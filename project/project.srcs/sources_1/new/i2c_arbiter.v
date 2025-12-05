module i2c_arbiter (
    input  wire       clk,
    input  wire       rst_n,

    // Client 0: BH1750
    input  wire       c0_req,
    input  wire       c0_rw,
    input  wire [6:0] c0_dev_addr,
    input  wire [7:0] c0_tx_data,
    output wire [7:0] c0_rx_data,
    output wire       c0_busy,
    output wire       c0_done,
    output wire       c0_ack_error,

    // Client 1: LM75
    input  wire       c1_req,
    input  wire       c1_rw,
    input  wire [6:0] c1_dev_addr,
    input  wire [7:0] c1_tx_data,
    output wire [7:0] c1_rx_data,
    output wire       c1_busy,
    output wire       c1_done,
    output wire       c1_ack_error,

    // Client 2: LCD (PCF8574)
    input  wire       c2_req,
    input  wire       c2_rw,
    input  wire [6:0] c2_dev_addr,
    input  wire [7:0] c2_tx_data,
    output wire [7:0] c2_rx_data,
    output wire       c2_busy,
    output wire       c2_done,
    output wire       c2_ack_error,

    // I2C master side
    output wire       m_start,
    output wire       m_rw,
    output wire [6:0] m_dev_addr,
    output wire [7:0] m_tx_data,
    input  wire [7:0] m_rx_data,
    input  wire       m_busy,
    input  wire       m_ack_error
);
    // TODO:
    //  - FSM chọn client nào active (ưu tiên sensor hay LCD tuỳ bạn)
    //  - map `m_*` <-> `c*_` tương ứng client hiện tại
endmodule
