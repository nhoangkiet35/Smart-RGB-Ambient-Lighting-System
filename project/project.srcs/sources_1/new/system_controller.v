module system_controller (
    input  wire        clk,
    input  wire        rst_n,

    // --- Sensor data (từ i2c_subsystem) ---
    input  wire [15:0] lux_value,
    input  wire        lux_valid,
    input  wire [15:0] temp_value,
    input  wire        temp_valid,

    // --- Điều khiển LCD ---
    output wire        lcd_update_req,
    input  wire        lcd_update_done,
    output wire [16*8-1:0] line1_text,
    output wire [16*8-1:0] line2_text,

    // --- Thông tin cho lighting_controller ---
    // brightness_level: mức sáng tổng thể (0..255)
    // base_rgb: màu cơ bản (pattern sẽ dựa trên màu này)
    output wire [7:0]  brightness_level,
    output wire [23:0] base_rgb
);
    // TODO: xử lý bên trong sau:
    //  - từ lux/temp -> brightness_level & base_rgb
    //  - từ lux/temp -> line1_text/line2_text -> lcd_update_req
endmodule
