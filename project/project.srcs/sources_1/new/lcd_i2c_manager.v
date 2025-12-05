//------------------------------------------------------------------------------
// lcd_i2c_manager.v
//  - Giao diện giữa system_controller và I2C bus cho LCD (PCF8574 + 16x2)
//  - Bên trong gọi:
//       + lcd_controller   : quản lý nội dung 2 dòng LCD
//       + lcd_byte_send    : gửi từng byte qua PCF8574 bằng I2C
//  - Bên ngoài nói chuyện với i2c_arbiter qua I2C client interface
//------------------------------------------------------------------------------

module lcd_i2c_manager (
    input  wire       clk,
    input  wire       rst_n,

    // ====== Từ system_controller ======
    input  wire       lcd_update_req,       // yêu cầu cập nhật lại LCD
    output wire       lcd_update_done,      // cập nhật xong
    input  wire [16*8-1:0] line1_text,      // 16 ký tự dòng 1
    input  wire [16*8-1:0] line2_text,      // 16 ký tự dòng 2

    // ====== I2C CLIENT interface tới i2c_arbiter ======
    output wire       i2c_req,        // yêu cầu 1 transaction (tương ứng i2c_start)
    output wire       i2c_rw,         // 0 = write (LCD chỉ ghi)
    output wire [6:0] i2c_dev_addr,   // địa chỉ PCF8574 (0x27/0x3F)
    output wire [7:0] i2c_tx_data,    // byte xuất lên I2C

    input  wire [7:0] i2c_rx_data,    // không dùng cho LCD (thường bỏ qua)
    input  wire       i2c_busy,       // arbiter + master bận với client này
    input  wire       i2c_done,       // transaction xong (hiện chưa dùng)
    input  wire       i2c_ack_error   // ACK lỗi
);

    //==========================================================================
    // Wires giữa lcd_controller và lcd_byte_send
    //==========================================================================
    wire       lbyte_start;
    wire [7:0] lbyte_data;
    wire       lbyte_rs;
    wire       lbyte_busy;
    wire       lbyte_done;

    //==========================================================================
    // Wires I2C từ lcd_byte_send (internal) sang I2C client interface
    //==========================================================================
    wire       core_i2c_start;
    wire [6:0] core_i2c_dev_addr;
    wire [7:0] core_i2c_tx_data;

    //==========================================================================
    // 1. LCD_CONTROLLER
    //    - Nhận update_req + text
    //    - Sinh ra lbyte_start / lbyte_data / lbyte_rs
    //    - Nhận lbyte_busy / lbyte_done để biết khi nào gửi xong 1 byte
    //==========================================================================
    lcd_controller u_lcd_controller (
        .clk            (clk),
        .rst_n          (rst_n),

        .update_req     (lcd_update_req),
        .update_done    (lcd_update_done),

        .line1_text     (line1_text),
        .line2_text     (line2_text),

        .lbyte_start    (lbyte_start),
        .lbyte_data     (lbyte_data),
        .lbyte_rs       (lbyte_rs),
        .lbyte_busy     (lbyte_busy),
        .lbyte_done     (lbyte_done)
    );

    //==========================================================================
    // 2. LCD_BYTE_SEND
    //    - Nhận 1 byte + RS
    //    - Convert sang nhiều lần write I2C (qua PCF8574)
    //    - Xuất ra core_i2c_start / core_i2c_dev_addr / core_i2c_tx_data
    //    - Nhận i2c_busy / i2c_ack_error từ arbiter/master
    //==========================================================================
    lcd_byte_send u_lcd_byte_send (
        .clk            (clk),
        .rst_n          (rst_n),

        .start          (lbyte_start),
        .lcd_byte       (lbyte_data),
        .rs             (lbyte_rs),

        .busy           (lbyte_busy),
        .done           (lbyte_done),

        .i2c_start      (core_i2c_start),
        .i2c_dev_addr   (core_i2c_dev_addr),
        .i2c_tx_data    (core_i2c_tx_data),

        .i2c_busy       (i2c_busy),
        .i2c_ack_error  (i2c_ack_error)
    );

    //==========================================================================
    // 3. Mapping sang I2C CLIENT interface
    //    - Ở mức skeleton, coi mỗi core_i2c_start là 1 "request" transaction
    //    - LCD chỉ ghi nên i2c_rw = 0
    //    - Địa chỉ & dữ liệu đi thẳng
    //    - i2c_rx_data, i2c_done hiện chưa dùng (LCD ít khi cần đọc)
    //==========================================================================
    assign i2c_req       = core_i2c_start;
    assign i2c_rw        = 1'b0;               // LCD chỉ write qua PCF8574
    assign i2c_dev_addr  = core_i2c_dev_addr;
    assign i2c_tx_data   = core_i2c_tx_data;

    // i2c_rx_data, i2c_done hiện không dùng bên trong
    // nhưng vẫn giữ port để interface với i2c_arbiter thống nhất
    // Nếu sau này muốn làm LCD read BF (busy flag), có thể dùng tới 2 tín hiệu này.

endmodule
