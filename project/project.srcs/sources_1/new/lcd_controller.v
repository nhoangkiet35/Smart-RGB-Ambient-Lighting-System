`timescale 1ns/1ps

//------------------------------------------------------------------------------
// lcd_controller (compact, no i2c_master inside)
//  - Điều khiển HD44780 (16x2, 4-bit mode) qua PCF8574
//  - Dùng lcd_byte_send để gửi từng byte
//  - Xuất giao diện i2c_req / i2c_rw / i2c_dev_addr / i2c_tx_data / i2c_busy / i2c_done
//
//  Flow:
//    - Sau reset: init LCD (4-bit mode, 2 line, clear, entry mode, display on).
//    - Sau đó vào IDLE, chờ update_req.
//    - Khi update_req = 1 pulse: ghi lại 2 dòng từ line1_text & line2_text.
//------------------------------------------------------------------------------
module lcd_controller #(
    parameter integer CLK_FREQ_HZ   = 125_000_000,  // clock hệ thống
    parameter [6:0]  LCD_I2C_ADDR   = 7'h27         // địa chỉ PCF8574
)(
    input  wire clk,
    input  wire rst,
    
    // Yêu cầu cập nhật từ System Controller
    input  wire       update_req,      // 1 pulse: cập nhật lại LCD
    output wire       update_done,     // 1 pulse: Hoàn thành việc ghi 2 dòng

    // Nội dung 2 dòng (16 ký tự/dòng, mỗi ký tự 8 bit)
    input  wire [16*8-1:0] line1_text, // [127:0]
    input  wire [16*8-1:0] line2_text,

    // ====== I2C CLIENT interface tới i2c_arbiter ======
    output wire       i2c_req,        // yêu cầu 1 transaction (tương ứng i2c_start)
    output wire       i2c_rw,         // 0 = write (LCD chỉ ghi)
    output wire [6:0] i2c_dev_addr,   // địa chỉ PCF8574 (0x27/0x3F)
    output wire [7:0] i2c_tx_data,    // byte PCF8574 cần gửi
    input  wire       i2c_busy,       // i2c_master đang bận
    input  wire       i2c_done        // i2c_master vừa xong 1 byte
);

    //======================================================================
    // 1. Timing cho HD44780
    //======================================================================

    localparam integer PWRUP_DELAY_US  = 15_000;   // 15 ms
    localparam integer CMD_DELAY_US    = 50;       // 50 µs
    localparam integer CLEAR_DELAY_US  = 2_000;    // 2 ms cho clear/home
    localparam integer CHAR_DELAY_US   = 50;       // 50 µs cho ghi ký tự

    localparam integer CLK_PER_US      = CLK_FREQ_HZ / 1_000_000;
    localparam integer PWRUP_DELAY_CYC = PWRUP_DELAY_US * CLK_PER_US;
    localparam integer CMD_DELAY_CYC   = CMD_DELAY_US   * CLK_PER_US;
    localparam integer CLEAR_DELAY_CYC = CLEAR_DELAY_US * CLK_PER_US;
    localparam integer CHAR_DELAY_CYC  = CHAR_DELAY_US  * CLK_PER_US;

    //======================================================================
    // 2. Kết nối tới lcd_byte_send
    //======================================================================

    reg        send_start;
    reg [7:0]  send_data;
    reg        send_rs;

    wire       send_busy;
    wire       send_done;

    wire       lcd_i2c_start;
    wire [7:0] lcd_i2c_data;

    lcd_byte_send #(
        .E_DELAY_CYCLES(200)          // thời gian giữ E=1 thêm sau I2C
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

    // Map sang I2C client interface
    assign i2c_req      = lcd_i2c_start;
    assign i2c_tx_data  = lcd_i2c_data;
    assign i2c_rw       = 1'b0;            // chỉ ghi
    assign i2c_dev_addr = LCD_I2C_ADDR;

    //======================================================================
    // 3. Lệnh LCD & ROM init
    //======================================================================

    localparam [7:0] CMD_FUNC_SET1  = 8'h03;
    localparam [7:0] CMD_FUNC_SET2  = 8'h33;
    localparam [7:0] CMD_FUNC_SET3  = 8'h30;
    localparam [7:0] CMD_SET_4BIT   = 8'h20;

    localparam [7:0] CMD_MODE_4BIT  = 8'h28;  // 4-bit, 2 line, 5x8
    localparam [7:0] CMD_DISPLAY_ON = 8'h0C;  // display on, cursor off
    localparam [7:0] CMD_ENTRY_MODE = 8'h06;  // tăng địa chỉ, không dịch màn hình
    localparam [7:0] CMD_CLEAR      = 8'h01;  // clear display
    localparam [7:0] CMD_DDRAM_0    = 8'h80;  // DDRAM addr 0 (dòng 1, cột 0)
    localparam [7:0] CMD_DDRAM_40   = 8'hC0;  // DDRAM addr 0x40 (dòng 2, cột 0)

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

    //======================================================================
    // 4. Lấy ký tự từ line1_text / line2_text theo index 0..31
    //    Giả sử: char 0 ở [7:0], char 1 ở [15:8], ...
    //======================================================================

    function [7:0] get_char;
        input [5:0] idx; // 0..31
        begin
            if (idx < 16)
                get_char = line1_text[idx*8 +: 8];
            else
                get_char = line2_text[(idx-16)*8 +: 8];
        end
    endfunction

    //======================================================================
    // 5. FSM chính
    //======================================================================

    localparam [3:0]
        ST_PWRUP       = 4'd0,
        ST_INIT_SEND   = 4'd1,
        ST_INIT_WAIT   = 4'd2,
        ST_IDLE        = 4'd3,
        ST_SET_LINE1   = 4'd4,
        ST_WAIT_LINE1  = 4'd5,
        ST_SEND_LINE1  = 4'd6,
        ST_SET_LINE2   = 4'd7,
        ST_WAIT_LINE2  = 4'd8,
        ST_SEND_LINE2  = 4'd9,
        ST_UPDATE_DONE = 4'd10;

    reg [3:0]  state = ST_PWRUP;
    reg [3:0]  init_idx;
    reg [5:0]  char_idx;        // 0..31 cho 2 dòng
    reg [31:0] delay_cnt;
    reg [31:0] delay_target = PWRUP_DELAY_CYC;
    reg [7:0]  cur_cmd;

    reg update_done_reg;

    assign update_done = update_done_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= ST_PWRUP;
            init_idx       <= 4'd0;
            char_idx       <= 6'd0;
            delay_cnt      <= 32'd0;
            delay_target   <= PWRUP_DELAY_CYC;
            send_start     <= 1'b0;
            send_data      <= 8'd0;
            send_rs        <= 1'b0;
            cur_cmd        <= 8'd0;
            update_done_reg<= 1'b0;
        end else begin
            send_start      <= 1'b0;     // default
            update_done_reg <= 1'b0;     // default (pulse 1 clock khi ST_UPDATE_DONE)

            case (state)
                //------------------------------------------------------------------
                // Chờ sau power-up
                //------------------------------------------------------------------
                ST_PWRUP: begin
                    if (delay_cnt < delay_target - 1) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt  <= 0;
                        init_idx   <= 4'd0;
                        state      <= ST_INIT_SEND;
                    end
                end

                //------------------------------------------------------------------
                // Gửi lần lượt các lệnh init
                //------------------------------------------------------------------
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
                        // Init xong -> vào IDLE, chờ update_req
                        state <= ST_IDLE;
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

                //------------------------------------------------------------------
                // ST_IDLE: chờ update_req từ system_controller
                //------------------------------------------------------------------
                ST_IDLE: begin
                    char_idx <= 6'd0;
                    if (update_req) begin   // assume update_req là 1 pulse
                        state <= ST_SET_LINE1;
                    end
                end

                //------------------------------------------------------------------
                // Gửi lệnh set DDRAM address dòng 1 (0x80)
                //------------------------------------------------------------------
                ST_SET_LINE1: begin
                    if (!send_busy) begin
                        if (!send_done && !send_start) begin
                            cur_cmd    <= CMD_DDRAM_0;
                            send_data  <= CMD_DDRAM_0;
                            send_rs    <= 1'b0;
                            send_start <= 1'b1;
                        end else if (send_done) begin
                            delay_cnt    <= 0;
                            delay_target <= CMD_DELAY_CYC;
                            state        <= ST_WAIT_LINE1;
                        end
                    end
                end

                ST_WAIT_LINE1: begin
                    if (delay_cnt < delay_target - 1) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt    <= 0;
                        delay_target <= CHAR_DELAY_CYC;
                        state        <= ST_SEND_LINE1;
                    end
                end

                //------------------------------------------------------------------
                // Ghi 16 ký tự dòng 1 (char_idx 0..15)
                //------------------------------------------------------------------
                ST_SEND_LINE1: begin
                    if (char_idx < 16) begin
                        if (!send_busy) begin
                            if (!send_done && !send_start) begin
                                send_data  <= get_char(char_idx);
                                send_rs    <= 1'b1;      // data
                                send_start <= 1'b1;
                            end else if (send_done) begin
                                char_idx     <= char_idx + 1'b1;
                                delay_cnt    <= 0;
                                delay_target <= CHAR_DELAY_CYC;
                                state        <= ST_WAIT_LINE1;
                            end
                        end
                    end else begin
                        // Hết dòng 1 -> chuyển sang dòng 2
                        state <= ST_SET_LINE2;
                    end
                end

                //------------------------------------------------------------------
                // Gửi lệnh set DDRAM address dòng 2 (0xC0)
                //------------------------------------------------------------------
                ST_SET_LINE2: begin
                    if (!send_busy) begin
                        if (!send_done && !send_start) begin
                            cur_cmd    <= CMD_DDRAM_40;
                            send_data  <= CMD_DDRAM_40;
                            send_rs    <= 1'b0;
                            send_start <= 1'b1;
                        end else if (send_done) begin
                            delay_cnt    <= 0;
                            delay_target <= CMD_DELAY_CYC;
                            state        <= ST_WAIT_LINE2;
                        end
                    end
                end

                ST_WAIT_LINE2: begin
                    if (delay_cnt < delay_target - 1) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt    <= 0;
                        delay_target <= CHAR_DELAY_CYC;
                        state        <= ST_SEND_LINE2;
                    end
                end

                //------------------------------------------------------------------
                // Ghi 16 ký tự dòng 2 (char_idx 16..31)
                //------------------------------------------------------------------
                ST_SEND_LINE2: begin
                    if (char_idx < 32) begin
                        if (!send_busy) begin
                            if (!send_done && !send_start) begin
                                send_data  <= get_char(char_idx);
                                send_rs    <= 1'b1;
                                send_start <= 1'b1;
                            end else if (send_done) begin
                                char_idx     <= char_idx + 1'b1;
                                delay_cnt    <= 0;
                                delay_target <= CHAR_DELAY_CYC;
                                state        <= ST_WAIT_LINE2;
                            end
                        end
                    end else begin
                        state <= ST_UPDATE_DONE;
                    end
                end

                //------------------------------------------------------------------
                // Phát xung update_done, sau đó quay về IDLE
                //------------------------------------------------------------------
                ST_UPDATE_DONE: begin
                    update_done_reg <= 1'b1;   // 1 clock pulse
                    state           <= ST_IDLE;
                end

                default: state <= ST_PWRUP;
            endcase
        end
    end

endmodule
