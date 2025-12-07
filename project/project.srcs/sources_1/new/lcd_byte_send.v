module lcd_byte_send (
    input  wire       clk,
    input  wire       rst,

    // Điều khiển phía trên
    input  wire       start,       // Bắt đầu gửi 1 byte
    input  wire [7:0] lcd_byte,    // Dữ liệu/command gửi tới LCD
    input  wire       rs,          // 0 = command, 1 = data

    output wire       busy,        // Đang bận
    output wire       done,        // Gửi xong 1 byte

    // Giao tiếp tới i2c_master (thực chất là tới PCF8574)
    output wire       i2c_start,
    output wire [6:0] i2c_dev_addr,  // Địa chỉ PCF8574 (0x27/0x3F)
    output wire [7:0] i2c_tx_data,   // Byte xuất cho PCF8574
    input  wire       i2c_busy,
    input  wire       i2c_ack_error
);
endmodule
