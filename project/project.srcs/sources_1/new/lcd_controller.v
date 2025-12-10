`timescale 1ns/1ps

//------------------------------------------------------------------------------
// lcd_controller (compact, no i2c_master inside)
//  - Điều khiển HD44780 (16x2, 4-bit mode) qua PCF8574
//  - Dùng lcd_byte_send để gửi từng byte
//  - Xuất giao diện i2c_req / i2c_rw / i2c_dev_addr / i2c_tx_data / i2c_busy / i2c_done ra TOP
//
//  Chain: lcd_controller -> lcd_byte_send -> i2c_master -> SDA/SCL
//------------------------------------------------------------------------------
module lcd_controller #(
    parameter integer CLK_FREQ_HZ   = 125_000_000,  // clock hệ thống
    parameter [6:0]  LCD_I2C_ADDR   = 7'h27         // chỉ dùng cho debug / thống nhất
)(
    input  wire clk,
    input  wire rst,
    
    // debug (tuỳ chọn)
//    output wire [4:0] dbg_state,
//    output wire [7:0] dbg_lcd_byte,
//    output wire       dbg_lcd_rs,
    
    // Yêu cầu cập nhật từ System Controller
    input  wire       update_req,      // 1 pulse: cập nhật lại LCD
    output wire       update_done,     // Hoàn thành

    // Nội dung 2 dòng (16 ký tự/dòng, mỗi ký tự 8 bit)
    input  wire [16*8-1:0] line1_text, // [127:0]
    input  wire [16*8-1:0] line2_text,

    // ====== I2C CLIENT interface tới i2c_arbiter ======
    output wire       i2c_req,        // yêu cầu 1 transaction (tương ứng i2c_start/i2c_newd)
    output wire       i2c_rw,         // 0 = write (LCD chỉ ghi)
    output wire [6:0] i2c_dev_addr,   // địa chỉ PCF8574 (0x27/0x3F)
    output wire [7:0] i2c_tx_data,     // byte PCF8574 cần gửi (i2c_data)
    input  wire       i2c_busy,     // i2c_master đang bận
    input  wire       i2c_done      // i2c_master vừa xong 1 byte
);

    //==========================================================================
    // 1. Timing cho HD44780
    //==========================================================================

    localparam integer PWRUP_DELAY_US  = 15_000;   // 15 ms
    localparam integer CMD_DELAY_US    = 2_000;    // 2 ms
    localparam integer CLEAR_DELAY_US  = 2_000;    // 2 ms cho clear/home
    localparam integer CHAR_DELAY_US   = 50;       // 50 µs cho ghi ký tự

    localparam integer CLK_PER_US      = CLK_FREQ_HZ / 1_000_000;
    localparam integer PWRUP_DELAY_CYC = PWRUP_DELAY_US * CLK_PER_US;
    localparam integer CMD_DELAY_CYC   = CMD_DELAY_US   * CLK_PER_US;
    localparam integer CLEAR_DELAY_CYC = CLEAR_DELAY_US * CLK_PER_US;
    localparam integer CHAR_DELAY_CYC  = CHAR_DELAY_US  * CLK_PER_US;

    //==========================================================================
    // 2. ROM text - ví dụ: "HELLO"
    //==========================================================================

    localparam integer TEXT_LEN = 5;

    function [7:0] text_byte;
        input [3:0] idx;
        begin
            case (idx)
                4'd0: text_byte = "H";
                4'd1: text_byte = "E";
                4'd2: text_byte = "L";
                4'd3: text_byte = "L";
                4'd4: text_byte = "O";
                default: text_byte = " ";
            endcase
        end
    endfunction

    //==========================================================================
    // 3. Kết nối tới lcd_byte_send
    //==========================================================================

    reg        send_start;
    reg [7:0]  send_data;
    reg        send_rs;

    wire       send_busy;
    wire       send_done;

    wire       lcd_i2c_start;
    wire [7:0] lcd_i2c_data;

    lcd_byte_send #(
        .E_DELAY_CYCLES(200)
    ) u_lcd_byte_send (
        .clk       (clk),
        .rst       (rst),
        .start     (send_start),
        .data      (send_data),
        .rs        (send_rs),
        .busy      (send_busy),
        .done      (send_done),
        .i2c_start (lcd_i2c_start),
        .i2c_data  (lcd_i2c_data),
        .i2c_busy  (i2c_busy),
        .i2c_done  (i2c_done)
    );

    assign i2c_req = lcd_i2c_start;
    assign i2c_tx_data = lcd_i2c_data;

    //==========================================================================
    // 4. Lệnh LCD & ROM init
    //==========================================================================

    localparam [7:0] CMD_FUNC_SET1  = 8'h03;  // phần lớn module I2C LCD đều ok
    localparam [7:0] CMD_FUNC_SET2  = 8'h33;
    localparam [7:0] CMD_FUNC_SET3  = 8'h30;
    localparam [7:0] CMD_SET_4BIT   = 8'h20;

    localparam [7:0] CMD_MODE_4BIT  = 8'h28;  // 4-bit, 2 line, 5x8
    localparam [7:0] CMD_DISPLAY_ON = 8'h0C;  // display on, cursor off
    localparam [7:0] CMD_ENTRY_MODE = 8'h06;  // tăng địa chỉ, không dịch màn hình
    localparam [7:0] CMD_CLEAR      = 8'h01;  // clear display
    localparam [7:0] CMD_DDRAM_0    = 8'h80;  // DDRAM addr 0 (dòng 1, cột 0)

    localparam integer INIT_LEN = 8;

    function [7:0] init_cmd;
        input [3:0] idx;
        begin
            case (idx)
                4'd0: init_cmd = CMD_FUNC_SET1;
                4'd1: init_cmd = CMD_FUNC_SET2;
                4'd2: init_cmd = CMD_FUNC_SET3;
                4'd3: init_cmd = CMD_SET_4BIT;
                4'd4: init_cmd = CMD_MODE_4BIT;
                4'd5: init_cmd = CMD_DISPLAY_ON;
                4'd6: init_cmd = CMD_CLEAR;
                4'd7: init_cmd = CMD_ENTRY_MODE;
                default: init_cmd = CMD_DDRAM_0;
            endcase
        end
    endfunction

    function [31:0] delay_for_cmd;
        input [7:0] cmd;
        begin
            if (cmd == CMD_CLEAR)
                delay_for_cmd = CLEAR_DELAY_CYC;
            else
                delay_for_cmd = CMD_DELAY_CYC;
        end
    endfunction

    //==========================================================================
    // 5. FSM chính
    //==========================================================================

    localparam [2:0]
        ST_PWRUP      = 3'd0,
        ST_INIT_SEND  = 3'd1,
        ST_INIT_WAIT  = 3'd2,
        ST_TEXT_SEND  = 3'd3,
        ST_TEXT_WAIT  = 3'd4,
        ST_DONE       = 3'd5;

    reg [2:0]  state;
    reg [3:0]  init_idx;
    reg [3:0]  char_idx;
    reg [31:0] delay_cnt;
    reg [31:0] delay_target;
    reg [7:0]  cur_cmd;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= ST_PWRUP;
            init_idx     <= 4'd0;
            char_idx     <= 4'd0;
            delay_cnt    <= 32'd0;
            delay_target <= PWRUP_DELAY_CYC;

            send_start   <= 1'b0;
            send_data    <= 8'd0;
            send_rs      <= 1'b0;
            cur_cmd      <= 8'd0;
        end else begin
            send_start <= 1'b0;  // default

            case (state)
                //------------------------------------------------------
                // Chờ sau power-up
                //------------------------------------------------------
                ST_PWRUP: begin
                    if (delay_cnt < delay_target - 1) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt    <= 0;
                        init_idx     <= 4'd0;
                        state        <= ST_INIT_SEND;
                    end
                end

                //------------------------------------------------------
                // Gửi lần lượt các lệnh init trong ROM
                //------------------------------------------------------
                ST_INIT_SEND: begin
                    if (init_idx < INIT_LEN) begin
                        if (!send_busy) begin
                            if (!send_done && !send_start) begin
                                cur_cmd    <= init_cmd(init_idx);
                                send_data  <= init_cmd(init_idx);
                                send_rs    <= 1'b0;     // command
                                send_start <= 1'b1;
                            end else if (send_done) begin
                                delay_cnt    <= 0;
                                delay_target <= delay_for_cmd(cur_cmd);
                                state        <= ST_INIT_WAIT;
                            end
                        end
                    end else begin
                        // init xong → set DDRAM address 0
                        if (!send_busy) begin
                            if (!send_done && !send_start) begin
                                cur_cmd    <= CMD_DDRAM_0;
                                send_data  <= CMD_DDRAM_0;
                                send_rs    <= 1'b0;
                                send_start <= 1'b1;
                            end else if (send_done) begin
                                delay_cnt    <= 0;
                                delay_target <= CMD_DELAY_CYC;
                                char_idx     <= 0;
                                state        <= ST_TEXT_WAIT;
                            end
                        end
                    end
                end

                ST_INIT_WAIT: begin
                    if (delay_cnt < delay_target - 1) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 0;
                        init_idx  <= init_idx + 1'b1;
                        state     <= ST_INIT_SEND;
                    end
                end

                //------------------------------------------------------
                // Chờ sau lệnh set DDRAM rồi ghi text
                //------------------------------------------------------
                ST_TEXT_WAIT: begin
                    if (delay_cnt < delay_target - 1) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt    <= 0;
                        delay_target <= CHAR_DELAY_CYC;
                        state        <= ST_TEXT_SEND;
                    end
                end

                //------------------------------------------------------
                // Ghi chuỗi "HELLO"
                //------------------------------------------------------
                ST_TEXT_SEND: begin
                    if (char_idx < TEXT_LEN) begin
                        if (!send_busy) begin
                            if (!send_done && !send_start) begin
                                send_data  <= text_byte(char_idx);
                                send_rs    <= 1'b1;   // data
                                send_start <= 1'b1;
                            end else if (send_done) begin
                                char_idx     <= char_idx + 1'b1;
                                delay_cnt    <= 0;
                                delay_target <= CHAR_DELAY_CYC;
                                state        <= ST_TEXT_WAIT;
                            end
                        end
                    end else begin
                        state <= ST_DONE;
                    end
                end

                //------------------------------------------------------
                ST_DONE: begin
                    state <= ST_DONE;
                end

                default: state <= ST_PWRUP;
            endcase
        end
    end

    //==========================================================================
    // Debug
    //==========================================================================
//    assign dbg_state    = {2'b00, state};
//    assign dbg_lcd_byte = send_data;
//    assign dbg_lcd_rs   = send_rs;

endmodule
