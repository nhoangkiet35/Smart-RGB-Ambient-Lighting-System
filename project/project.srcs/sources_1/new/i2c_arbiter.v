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
    output wire        req,
    output wire        rw,         // 0 = write, 1 = read
    output wire [6:0]  dev_addr,   // 7-bit I2C address
    output wire [7:0]  tx_data     // byte gửi vào i2c_master.rx_data
);
    // Ở giai đoạn test LCD, ta ưu tiên:
    //  - c2 (LCD) > c0 (BH1750) > c1 (LM75)

    reg        req_r;
    reg        rw_r;
    reg [6:0]  dev_addr_r;
    reg [7:0]  tx_data_r;

    always @(*) begin
        // default: không yêu cầu
        req_r      = 1'b0;
        rw_r       = 1'b0;
        dev_addr_r = 7'd0;
        tx_data_r  = 8'd0;

        if (c2_req) begin
            req_r      = 1'b1;
            rw_r       = c2_rw;
            dev_addr_r = c2_dev_addr;
            tx_data_r  = c2_rx_data;
        end else if (c0_req) begin
            req_r      = 1'b1;
            rw_r       = c0_rw;
            dev_addr_r = c0_dev_addr;
            tx_data_r  = c0_rx_data;
        end else if (c1_req) begin
            req_r      = 1'b1;
            rw_r       = c1_rw;
            dev_addr_r = c1_dev_addr;
            tx_data_r  = c1_rx_data;
        end
    end

    assign req      = req_r;
    assign rw       = rw_r;
    assign dev_addr = dev_addr_r;
    assign tx_data  = tx_data_r;

endmodule
