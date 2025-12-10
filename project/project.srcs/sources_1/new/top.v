`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// top.v
//  - Toplevel tích hợp toàn bộ hệ thống Smart RGB Ambient Lighting System
// -----------------------------------------------------------------------------
//  Bus I2C dùng chung cho:
//   - BH1750 (lux)
//   - LM75  (temp)
//   - LCD HD44780 qua PCF8574
//  Ánh sáng WS2812 điều khiển qua lighting_controller.
// -----------------------------------------------------------------------------
module top (
    input  wire clk,          // Clock 125 MHz
    input  wire rst,          // Active-high reset
    inout  wire i2c_sda,
    output wire i2c_scl,
    output wire ws2812_dout   // Kết nối tới dải WS2812
);

    // -------------------------------------------------------------------------
    // 1. Wires chung cho I2C master <-> arbiter <-> clients
    // -------------------------------------------------------------------------

    // Arbiter -> i2c_master
    wire        arb_req;          // start
    wire        arb_rw;           // 0=write, 1=read
    wire [6:0]  arb_dev_addr;
    wire [7:0]  arb_tx_data;      // đi vào i2c_master.rx_data

    // i2c_master -> các client
    wire [7:0]  i2c_bus_rx_data;  // dữ liệu đọc từ bus (i2c_master.tx_data)
    wire        i2c_busy;
    wire        i2c_done;
    wire        i2c_ack_err;

    // -------------------------------------------------------------------------
    // 2. I2C master (nói chuyện với SDA/SCL thật) (PASSED)
    // -------------------------------------------------------------------------
    i2c_master #(
        .SYS_FREQ(125_000_000),
        .I2C_FREQ(100_000)
    ) u_i2c_master (
        .clk      (clk),
        .rst      (rst),
        .start    (arb_req),
        .rw       (arb_rw),
        .dev_addr (arb_dev_addr),

        // lưu ý: trong i2c_master.v, 'rx_data' là byte cần GHI ra bus
        //       còn 'tx_data' là byte ĐỌC về từ slave
        .i2c_sda  (i2c_sda),
        .i2c_scl  (i2c_scl),
        .rx_data  (arb_tx_data),      // data từ arbiter/clients
        .tx_data  (i2c_bus_rx_data),  // data trả về cho các client

        .busy     (i2c_busy),
        .ack_err  (i2c_ack_err),
        .done     (i2c_done)
    );

    // -------------------------------------------------------------------------
    // 3. Wires cho từng client I2C
    // -------------------------------------------------------------------------

    // --- BH1750 (Client 0) ---
    wire [15:0] lux_value;

    wire        c0_req;
    wire        c0_rw;
    wire [6:0]  c0_dev_addr;
    wire [7:0]  c0_tx_data;   // byte cần gửi

    // --- LM75 (Client 1) ---
    wire [15:0] temp_value;

    wire        c1_req;
    wire        c1_rw;
    wire [6:0]  c1_dev_addr;
    wire [7:0]  c1_tx_data;

    // --- LCD (Client 2) ---
    localparam [6:0] LCD_I2C_ADDR = 7'h27;   // hoặc 7'h3F tuỳ module thật

    wire        c2_req;
    wire        c2_rw;
    wire [6:0]  c2_dev_addr;
    wire [7:0]  c2_tx_data;

    // -------------------------------------------------------------------------
    // 4. i2c_arbiter: chọn 1 client đẩy yêu cầu sang i2c_master (FULFILLED)
    // -------------------------------------------------------------------------
    i2c_arbiter u_i2c_arbiter (
        .clk        (clk),
        .rst        (rst),

        // Client 0: BH1750
        .c0_req      (c0_req),
        .c0_rw       (c0_rw),
        .c0_dev_addr (c0_dev_addr),
        .c0_rx_data  (c0_tx_data),

        // Client 1: LM75
        .c1_req      (c1_req),
        .c1_rw       (c1_rw),
        .c1_dev_addr (c1_dev_addr),
        .c1_rx_data  (c1_tx_data),

        // Client 2: LCD
        .c2_req      (c2_req),
        .c2_rw       (c2_rw),
        .c2_dev_addr (c2_dev_addr),
        .c2_rx_data  (c2_tx_data),

        // I2C master side
        .req         (arb_req),
        .rw          (arb_rw),
        .dev_addr    (arb_dev_addr),
        .tx_data     (arb_tx_data)   // đi vào i2c_master.rx_data
    );

    // -------------------------------------------------------------------------
    // 5. BH1750 client (lux sensor) - hiện mới là skeleton (DOING)
    // -------------------------------------------------------------------------
    bh1750_client u_bh1750 (
        .clk          (clk),
        .rst          (rst),

        .lux_value    (lux_value),

        // I2C client interface
        .i2c_req      (c0_req),
        .i2c_rw       (c0_rw),
        .i2c_dev_addr (c0_dev_addr),
        .i2c_tx_data  (c0_tx_data),
        .i2c_rx_data  (i2c_bus_rx_data),
        .i2c_busy     (i2c_busy),
        .i2c_done     (i2c_done),
        .i2c_ack_error(i2c_ack_err)
    );

    // -------------------------------------------------------------------------
    // 6. LM75 client (temp sensor) - cũng đang ở mức skeleton (DOING)
    // -------------------------------------------------------------------------
    lm75_client u_lm75 (
        .clk          (clk),
        .rst          (rst),

        .temp_value   (temp_value),

        // I2C client interface
        .i2c_req      (c1_req),
        .i2c_rw       (c1_rw),
        .i2c_dev_addr (c1_dev_addr),
        .i2c_tx_data  (c1_tx_data),
        .i2c_rx_data  (i2c_bus_rx_data),
        .i2c_busy     (i2c_busy),
        .i2c_done     (i2c_done),
        .i2c_ack_error(i2c_ack_err)
    );

    // -------------------------------------------------------------------------
    // 7. LCD controller (HD44780 + PCF8574) - client 2 của I2C (PENDING)
    // -------------------------------------------------------------------------
    wire        lcd_update_req;
    wire        lcd_update_done;
    wire [127:0] line1_text;
    wire [127:0] line2_text;

    lcd_controller #(
        .CLK_FREQ_HZ   (125_000_000),
        .LCD_I2C_ADDR  (LCD_I2C_ADDR)
    ) u_lcd_controller (
        .clk          (clk),
        .rst          (rst),

        .update_req   (lcd_update_req),
        .update_done  (lcd_update_done),

        .line1_text   (line1_text),
        .line2_text   (line2_text),

        // I2C client interface
        .i2c_req      (c2_req),
        .i2c_rw       (c2_rw),
        .i2c_dev_addr (c2_dev_addr),
        .i2c_tx_data  (c2_tx_data),
        .i2c_busy     (i2c_busy),
        .i2c_done     (i2c_done)
    );

    // -------------------------------------------------------------------------
    // 8. System controller: nhận lux/temp -> quyết định brightness + base_rgb
    //    đồng thời format nội dung LCD (DONE)
    // -------------------------------------------------------------------------
    wire [7:0]  brightness_level;
    wire [23:0] base_rgb;

    system_controller u_system_controller (
        .clk             (clk),
        .rst             (rst),

        .lux_value       (lux_value),
        .temp_value      (temp_value),

        .lcd_update_done (lcd_update_done),
        .lcd_update_req  (lcd_update_req),
        .line1_text      (line1_text),
        .line2_text      (line2_text),

        .brightness_level(brightness_level),
        .base_rgb        (base_rgb)
    );

    // -------------------------------------------------------------------------
    // 9. Lighting controller: sinh pattern + scale brightness -> WS2812 (DONE)
    // -------------------------------------------------------------------------
    // brightness_level = 15 (max) → đèn sáng mạnh
    // wire [7:0] brightness_level = 8'd2;
    // base_rgb đại diện cho nhiệt độ 25-45°C (màu lạnh → nóng)
    // Ví dụ: 34°C → Yellow-Green (128,255,0)
    // wire [23:0] base_rgb = {8'd0, 8'd225, 8'd128};
    // Tự động generate pattern mỗi frame và gửi xuống ws2812_chain → ws2812_pixel_driver
    lighting_controller #(.NUM_LEDS(64)) lighting_ctrl_inst (
        .clk(clk),
        .rst(rst),
        .brightness_level(brightness_level),
        .base_rgb(base_rgb),
        .data_out(ws2812_dout)
    );

endmodule
