module top (
    input  wire clk,        // 125 MHz
    input  wire rst_n,      // Active-low reset

    inout  wire i2c_sda,
    output wire i2c_scl,

    output wire ws2812_dout
);

    localparam NUM_LEDS = 16;

    // ====================================================
    // 1. Wires từ i2c_subsystem (sensor + LCD)
    // ====================================================
    wire [15:0] lux_value;
    wire        lux_valid;
    wire [15:0] temp_value;
    wire        temp_valid;

    wire        lcd_update_req;
    wire        lcd_update_done;
    wire [16*8-1:0] line1_text;
    wire [16*8-1:0] line2_text;

    // ====================================================
    // 2. Wires cho LED path
    // ====================================================
    wire [NUM_LEDS*24-1:0] led_data;
    wire                    ws_start;
    wire                    ws_done;

    // Thông tin trung gian từ system_controller -> lighting_controller
    wire [7:0]              brightness_level;
    wire [23:0]             base_rgb;

    // ====================================================
    // 3. SYSTEM CONTROLLER (sensor -> LCD + brightness/base_rgb)
    // ====================================================
    system_controller u_sys_ctrl (
        .clk            (clk),
        .rst_n          (rst_n),

        // --- Sensor data ---
        .lux_value      (lux_value),
        .lux_valid      (lux_valid),
        .temp_value     (temp_value),
        .temp_valid     (temp_valid),

        // --- LCD ---
        .lcd_update_req (lcd_update_req),
        .lcd_update_done(lcd_update_done),
        .line1_text     (line1_text),
        .line2_text     (line2_text),

        // --- Cho lighting_controller ---
        .brightness_level (brightness_level),
        .base_rgb          (base_rgb)
    );

    // ====================================================
    // 4. I2C SUBSYSTEM (BH1750 + LM75 + LCD + I2C master)
    // ====================================================
    i2c_subsystem #(
        .CLK_FREQ_HZ(125_000_000),
        .I2C_FREQ_HZ(100_000)
    ) u_i2c_subsystem (
        .clk            (clk),
        .rst_n          (rst_n),

        .i2c_sda        (i2c_sda),
        .i2c_scl        (i2c_scl),

        .lux_value      (lux_value),
        .lux_valid      (lux_valid),
        .temp_value     (temp_value),
        .temp_valid     (temp_valid),

        .lcd_update_req (lcd_update_req),
        .lcd_update_done(lcd_update_done),
        .line1_text     (line1_text),
        .line2_text     (line2_text)
    );

    // ====================================================
    // 5. LIGHTING CONTROLLER (brightness_level + base_rgb -> led_data)
    // ====================================================
    lighting_controller #(
        .NUM_LEDS(NUM_LEDS)
    ) u_lighting (
        .clk              (clk),
        .rst_n            (rst_n),

        .brightness_level (brightness_level),
        .base_rgb         (base_rgb),

        .led_data         (led_data),
        .ws_start         (ws_start)
    );

    // ====================================================
    // 6. WS2812 CHAIN
    // ====================================================
    ws2812_chain #(
        .NUM_LEDS(NUM_LEDS)
    ) u_ws_chain (
        .clk        (clk),
        .rst_n      (rst_n),

        .start      (ws_start),
        .led_data   (led_data),

        .data_out   (ws2812_dout),
        .done       (ws_done)
    );

endmodule
