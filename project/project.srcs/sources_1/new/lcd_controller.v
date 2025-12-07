module lcd_controller (
    input  wire       clk,
    input  wire       rst,

    // Yêu cầu cập nhật từ System Controller
    input  wire       update_req,      // 1 pulse: cập nhật lại LCD
    output wire       update_done,     // Hoàn thành

    // Nội dung 2 dòng (16 ký tự/dòng, mỗi ký tự 8 bit)
    input  wire [16*8-1:0] line1_text, // [127:0]
    input  wire [16*8-1:0] line2_text,

    // ====== I2C CLIENT interface tới i2c_arbiter ======
    output wire       i2c_req,        // yêu cầu 1 transaction (tương ứng i2c_start)
    output wire       i2c_rw,         // 0 = write (LCD chỉ ghi)
    output wire [6:0] i2c_dev_addr,   // địa chỉ PCF8574 (0x27/0x3F)
    output wire [7:0] i2c_tx_data,    // byte xuất lên I2C

    // Giao tiếp xuống lcd_byte_send
    output wire       lbyte_start,
    output wire [7:0] lbyte_data,
    output wire       lbyte_rs,        // 0=cmd, 1=data
    input  wire       lbyte_busy,
    input  wire       lbyte_done
);
endmodule
