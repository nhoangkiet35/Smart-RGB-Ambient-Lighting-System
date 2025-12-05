//------------------------------------------------------------------------------
// i2c_subsystem.v
//  - Chứa: i2c_master + (logic đọc BH1750, LM75) + LCD (lcd_controller + lcd_byte_send)
//  - Bên ngoài chỉ thấy: SDA/SCL + lux/temp + LCD text
//------------------------------------------------------------------------------
module i2c_subsystem #(
    parameter integer CLK_FREQ_HZ = 125_000_000,
    parameter integer I2C_FREQ_HZ = 100_000
)(
    input  wire       clk,
    input  wire       rst_n,

    // ---- I2C physical pins ----
    inout  wire       i2c_sda,
    output wire       i2c_scl,

    // ---- Sensor outputs (ra cho system_controller) ----
    output wire [15:0] lux_value,    // BH1750
    output wire        lux_valid,
    output wire [15:0] temp_value,   // LM75
    output wire        temp_valid,

    // ---- LCD interface từ system_controller ----
    input  wire        lcd_update_req,
    output wire        lcd_update_done,
    input  wire [16*8-1:0] line1_text,
    input  wire [16*8-1:0] line2_text
);

    // 1) i2c_master ↔ arbiter
    wire       m_start;
    wire       m_rw;
    wire [6:0] m_dev_addr;
    wire [7:0] m_tx_data;
    wire [7:0] m_rx_data;
    wire       m_busy;
    wire       m_ack_error;

    i2c_master #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I2C_FREQ_HZ(I2C_FREQ_HZ)
    ) u_i2c_master (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (m_start),
        .rw        (m_rw),
        .dev_addr  (m_dev_addr),
        .tx_data   (m_tx_data),
        .rx_data   (m_rx_data),
        .busy      (m_busy),
        .ack_error (m_ack_error),
        .i2c_sda   (i2c_sda),
        .i2c_scl   (i2c_scl)
    );

    // 2) BH1750 client wires
    wire       bh_req, bh_rw, bh_busy, bh_done, bh_ack;
    wire [6:0] bh_addr;
    wire [7:0] bh_tx, bh_rx;

    bh1750_client u_bh (
        .clk           (clk),
        .rst_n         (rst_n),
        .lux_value     (lux_value),
        .lux_valid     (lux_valid),

        .i2c_req       (bh_req),
        .i2c_rw        (bh_rw),
        .i2c_dev_addr  (bh_addr),
        .i2c_tx_data   (bh_tx),
        .i2c_rx_data   (bh_rx),
        .i2c_busy      (bh_busy),
        .i2c_done      (bh_done),
        .i2c_ack_error (bh_ack)
    );

    // 3) LM75 client wires
    wire       lm_req, lm_rw, lm_busy, lm_done, lm_ack;
    wire [6:0] lm_addr;
    wire [7:0] lm_tx, lm_rx;

    lm75_client u_lm (
        .clk           (clk),
        .rst_n         (rst_n),
        .temp_value    (temp_value),
        .temp_valid    (temp_valid),

        .i2c_req       (lm_req),
        .i2c_rw        (lm_rw),
        .i2c_dev_addr  (lm_addr),
        .i2c_tx_data   (lm_tx),
        .i2c_rx_data   (lm_rx),
        .i2c_busy      (lm_busy),
        .i2c_done      (lm_done),
        .i2c_ack_error (lm_ack)
    );

    // 4) LCD manager wires
    wire       lcd_req, lcd_rw, lcd_busy, lcd_done, lcd_ack;
    wire [6:0] lcd_addr;
    wire [7:0] lcd_tx, lcd_rx;

    lcd_i2c_manager u_lcd_mgr (
        .clk            (clk),
        .rst_n          (rst_n),
        .lcd_update_req (lcd_update_req),
        .lcd_update_done(lcd_update_done),
        .line1_text     (line1_text),
        .line2_text     (line2_text),

        .i2c_req        (lcd_req),
        .i2c_rw         (lcd_rw),
        .i2c_dev_addr   (lcd_addr),
        .i2c_tx_data    (lcd_tx),
        .i2c_rx_data    (lcd_rx),
        .i2c_busy       (lcd_busy),
        .i2c_done       (lcd_done),
        .i2c_ack_error  (lcd_ack)
    );

    // 5) I2C arbiter với 3 client
    i2c_arbiter u_arb (
        .clk        (clk),
        .rst_n      (rst_n),

        // client 0: BH1750
        .c0_req         (bh_req),
        .c0_rw          (bh_rw),
        .c0_dev_addr    (bh_addr),
        .c0_tx_data     (bh_tx),
        .c0_rx_data     (bh_rx),
        .c0_busy        (bh_busy),
        .c0_done        (bh_done),
        .c0_ack_error   (bh_ack),

        // client 1: LM75
        .c1_req         (lm_req),
        .c1_rw          (lm_rw),
        .c1_dev_addr    (lm_addr),
        .c1_tx_data     (lm_tx),
        .c1_rx_data     (lm_rx),
        .c1_busy        (lm_busy),
        .c1_done        (lm_done),
        .c1_ack_error   (lm_ack),

        // client 2: LCD
        .c2_req         (lcd_req),
        .c2_rw          (lcd_rw),
        .c2_dev_addr    (lcd_addr),
        .c2_tx_data     (lcd_tx),
        .c2_rx_data     (lcd_rx),
        .c2_busy        (lcd_busy),
        .c2_done        (lcd_done),
        .c2_ack_error   (lcd_ack),

        // master side
        .m_start        (m_start),
        .m_rw           (m_rw),
        .m_dev_addr     (m_dev_addr),
        .m_tx_data      (m_tx_data),
        .m_rx_data      (m_rx_data),
        .m_busy         (m_busy),
        .m_ack_error    (m_ack_error)
    );

endmodule
