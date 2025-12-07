module i2c_master #(
    parameter integer CLK_FREQ_HZ = 125_000_000,
    parameter integer I2C_FREQ_HZ = 100_000
)(
    input  wire        clk,
    input  wire        rst,

    // Simple command interface
//    input  wire        start,      // 1 pulse to start a transaction
    input  wire       req,
    input  wire        rw,         // 0 = write, 1 = read
    input  wire [6:0]  dev_addr,   // 7-bit I2C address
//    input  wire [7:0]  tx_data,    // Byte to transmit
    input wire [7:0]  rx_data,    // Byte received

//    output wire        busy,       // Master is busy
//    output wire        ack_error,  // ACK error detected

    // I2C lines
    inout  wire        i2c_sda,
    output wire        i2c_scl
);
endmodule
