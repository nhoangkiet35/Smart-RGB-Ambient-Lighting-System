module bh1750_client (
    input  wire       clk,
    input  wire       rst_n,

    // Kết quả đưa ra ngoài subsystem
    output wire [15:0] lux_value,   // giá trị lux (raw hoặc đã scale)
    output wire        lux_valid,   // 1 pulse khi cập nhật lux_value mới

    // Giao diện I2C client tới i2c_arbiter
    output wire        i2c_req,        // yêu cầu dùng I2C
    output wire        i2c_rw,         // 0=write, 1=read
    output wire [6:0]  i2c_dev_addr,   // địa chỉ BH1750 (0x23/0x5C)
    output wire [7:0]  i2c_tx_data,    // byte gửi đi (lệnh cấu hình, v.v.)
    input  wire [7:0]  i2c_rx_data,    // byte đọc về
    input  wire        i2c_busy,       // arbiter + master đang bận
    input  wire        i2c_done,       // transaction kết thúc
    input  wire        i2c_ack_error   // lỗi ACK
);
    // TODO:
    //  - FSM nội bộ:
    //      + định kỳ gửi lệnh start measurement cho BH1750
    //      + sau delay phù hợp, yêu cầu read 2 byte
    //      + ghép thành lux_value, nhá lux_valid
endmodule
