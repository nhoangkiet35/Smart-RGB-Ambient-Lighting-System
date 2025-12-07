module i2c_arbiter (
    input  wire       clk,
    input  wire       rst,

    // Client 0: BH1750
    input  wire       c0_req,
    input  wire       c0_rw,
    input  wire [6:0] c0_dev_addr,
    input  wire [7:0] c0_rx_data,

    // Client 1: LM75
    input  wire       c1_req,
    input  wire       c1_rw,
    input  wire [6:0] c1_dev_addr,
    input  wire [7:0] c1_rx_data,

    // Client 2: LCD (PCF8574)
    input  wire       c2_req,
    input  wire       c2_rw,
    input  wire [6:0] c2_dev_addr,
    input  wire [7:0] c2_rx_data,

    // I2C master side
    output  wire        req,
    output  wire        rw,         // 0 = write, 1 = read
    output  wire [6:0]  dev_addr,   // 7-bit I2C address
    output  wire [7:0]  tx_data     // Byte received
);
    // TODO:
    //  - FSM chọn client nào active (ưu tiên sensor hay LCD tuỳ bạn)
    //  - map `m_*` <-> `c*_` tương ứng client hiện tại
endmodule
