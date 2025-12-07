module lm75_client (
    input  wire       clk,
    input  wire       rst,

    // Kết quả đưa ra ngoài subsystem
    output wire [15:0] temp_value,   // nhiệt độ (raw hoặc đã scale)

    // Giao diện I2C client tới i2c_arbiter
    output wire        i2c_req,        // yêu cầu dùng I2C
    output wire        i2c_rw,         // 0=write, 1=read
    output wire [6:0]  i2c_dev_addr,   // địa chỉ LM75 (0x48..0x4F)
    output wire [7:0]  i2c_tx_data,    // byte gửi đi (ví dụ chọn register)
    input  wire [7:0]  i2c_rx_data,    // byte đọc về
    input  wire        i2c_busy,
    input  wire        i2c_done,
    input  wire        i2c_ack_error
);
    // TODO:
    //  - FSM nội bộ:
    //      + ghi pointer tới register temperature (nếu cần)
    //      + read 2 byte nhiệt độ định kỳ
    //      + xuất temp_value + temp_valid
endmodule
