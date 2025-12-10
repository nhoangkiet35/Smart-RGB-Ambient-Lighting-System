`timescale 1ns/1ps

//------------------------------------------------------------------------------
// lcd_byte_send
//   - Gửi 1 byte lệnh/dữ liệu tới HD44780 qua PCF8574 (I2C)
//   - Thực hiện 4 lần ghi I2C:
//       1) high nibble, E=1
//       2) high nibble, E=0
//       3) low  nibble, E=1
//       4) low  nibble, E=0
//   - KHÔNG gọi i2c_master bên trong, chỉ giao tiếp qua i2c_newd/i2c_data
//------------------------------------------------------------------------------

module lcd_byte_send #(
    // Số chu kỳ clk để giữ thêm E=1 sau khi I2C xong (giữa E1 và E0)
    parameter integer E_DELAY_CYCLES = 200  // tuỳ ý, ví dụ 200 chu kỳ @125MHz ≈ 1.6µs
)(
    input  wire       clk,
    input  wire       rst,

    input  wire       start,    // 1 xung clock để bắt đầu gửi 1 byte
    input  wire [7:0] data,     // byte lệnh/dữ liệu LCD
    input  wire       rs,       // 0 = command, 1 = data

    output reg        busy,     // =1 trong suốt quá trình gửi (4 lần I2C)
    output reg        done,     // xung 1 clock khi hoàn thành

    // Giao diện tới tầng I2C ở trên (top / i2c_manager)
    output reg        i2c_start, // pulse 1 clock: có byte mới cần gửi
    output reg [7:0]  i2c_data, // dữ liệu byte PCF8574
    input  wire       i2c_busy, // master I2C đang bận
    input  wire       i2c_done  // master I2C vừa xong 1 byte
);

    //======================================================================
    // 1. Bộ nhớ tạm
    //======================================================================
    reg [7:0] data_latched;
    reg       rs_latched;

    reg [3:0] hi_nibble;
    reg [3:0] lo_nibble;

    //======================================================================
    // 2. Hàm mã hoá nibble LCD -> byte PCF8574
    //======================================================================
    function [7:0] make_pcf8574;
        input [3:0] nib;
        input       e_bit;
        input       rs_bit;
        begin
            // nibble đi vào D7..D4 (bit7..4)
            make_pcf8574[7:4] = nib;
            make_pcf8574[3]   = 1'b1;     // BL = 1 (bật nền)
            make_pcf8574[2]   = e_bit;    // E
            make_pcf8574[1]   = 1'b0;     // RW = 0 (ghi)
            make_pcf8574[0]   = rs_bit;   // RS
        end
    endfunction

    //======================================================================
    // 3. FSM gửi 4 lần I2C
    //======================================================================
    localparam [3:0]
        ST_IDLE       = 4'd0,
        ST_SEND_HI_E1 = 4'd1,
        ST_WAIT_HI_E1 = 4'd2,   // chờ I2C + giữ thêm E=1
        ST_SEND_HI_E0 = 4'd3,
        ST_WAIT_HI_E0 = 4'd4,
        ST_SEND_LO_E1 = 4'd5,
        ST_WAIT_LO_E1 = 4'd6,
        ST_SEND_LO_E0 = 4'd7,
        ST_WAIT_LO_E0 = 4'd8,
        ST_DONE       = 4'd9;

    reg [3:0]  state;
    reg [15:0] e_delay_cnt;   // đủ lớn cho E_DELAY_CYCLES

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= ST_IDLE;
            busy         <= 1'b0;
            done         <= 1'b0;

            data_latched <= 8'd0;
            rs_latched   <= 1'b0;
            hi_nibble    <= 4'd0;
            lo_nibble    <= 4'd0;

            i2c_start     <= 1'b0;
            i2c_data     <= 8'd0;

            e_delay_cnt  <= 16'd0;
        end else begin
            // mặc định mỗi clock
            done     <= 1'b0;   // chỉ pulse 1 clock khi xong
            i2c_start <= 1'b0;   // newd cũng chỉ pulse 1 clock

            case (state)
                //------------------------------------------------------
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        data_latched <= data;
                        rs_latched   <= rs;
                        hi_nibble    <= data[7:4];
                        lo_nibble    <= data[3:0];
                        busy         <= 1'b1;
                        state        <= ST_SEND_HI_E1;
                    end
                end

                //------------------------------------------------------
                // 1) Gửi high nibble, E=1
                //------------------------------------------------------
                ST_SEND_HI_E1: begin
                    busy <= 1'b1;
                    if (!i2c_busy && !i2c_done) begin
                        i2c_data <= make_pcf8574(hi_nibble, 1'b1, rs_latched);
                        i2c_start <= 1'b1;         // yêu cầu master gửi byte này
                        e_delay_cnt <= 16'd0;     // reset counter để dùng sau
                        state    <= ST_WAIT_HI_E1;
                    end
                end

                // Chờ I2C xong + giữ thêm E=1 một khoảng
                ST_WAIT_HI_E1: begin
                    busy <= 1'b1;
                    if (!i2c_done) begin
                        // còn đang gửi I2C → E vẫn giữ high trong suốt thời gian này
                        e_delay_cnt <= 16'd0;     // chưa bắt đầu đếm hold
                    end else begin
                        // I2C đã xong → bắt đầu đếm hold E=1
                        if (e_delay_cnt < E_DELAY_CYCLES) begin
                            e_delay_cnt <= e_delay_cnt + 1'b1;
                        end else begin
                            e_delay_cnt <= 16'd0;
                            state       <= ST_SEND_HI_E0;
                        end
                    end
                end

                //------------------------------------------------------
                // 2) Gửi high nibble, E=0
                //------------------------------------------------------
                ST_SEND_HI_E0: begin
                    busy <= 1'b1;
                    if (!i2c_busy && !i2c_done) begin
                        i2c_data <= make_pcf8574(hi_nibble, 1'b0, rs_latched);
                        i2c_start <= 1'b1;
                        state    <= ST_WAIT_HI_E0;
                    end
                end
                
                ST_WAIT_HI_E0: begin
                    busy <= 1'b1;
                    if (i2c_done) begin
                        state <= ST_SEND_LO_E1;
                    end
                end

                //------------------------------------------------------
                // 3) Gửi low nibble, E=1
                //------------------------------------------------------
                ST_SEND_LO_E1: begin
                    busy <= 1'b1;
                    if (!i2c_busy && !i2c_done) begin
                        i2c_data <= make_pcf8574(lo_nibble, 1'b1, rs_latched);
                        i2c_start <= 1'b1;
                        e_delay_cnt <= 16'd0;
                        state    <= ST_WAIT_LO_E1;
                    end
                end

                ST_WAIT_LO_E1: begin
                    busy <= 1'b1;
                    if (!i2c_done) begin
                        e_delay_cnt <= 16'd0;
                    end else begin
                        if (e_delay_cnt < E_DELAY_CYCLES) begin
                            e_delay_cnt <= e_delay_cnt + 1'b1;
                        end else begin
                            e_delay_cnt <= 16'd0;
                            state       <= ST_SEND_LO_E0;
                        end
                    end
                end

                //------------------------------------------------------
                // 4) Gửi low nibble, E=0
                //------------------------------------------------------
                ST_SEND_LO_E0: begin
                    busy <= 1'b1;
                    if (!i2c_busy && !i2c_done) begin
                        i2c_data <= make_pcf8574(lo_nibble, 1'b0, rs_latched);
                        i2c_start <= 1'b1;
                        state    <= ST_WAIT_LO_E0;
                    end
                end

                ST_WAIT_LO_E0: begin
                    busy <= 1'b1;
                    if (i2c_done) begin
                        state <= ST_DONE;
                    end
                end

                //------------------------------------------------------
                // Hoàn thành
                //------------------------------------------------------
                ST_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;     // xung báo hoàn thành 1 byte
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule
