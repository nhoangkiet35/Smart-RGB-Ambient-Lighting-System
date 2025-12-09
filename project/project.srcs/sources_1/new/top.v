// -----------------------------------------------------------------------------
// top.v
//  - Toplevel tích hợp toàn bộ hệ thống
// -----------------------------------------------------------------------------
module top (
    input  wire clk,          // Clock 125 MHz
    input  wire rst,          // Active-high reset
    inout  wire i2c_sda,
    output wire i2c_scl,
    output wire ws2812_dout   // Kết nối tới dải WS2812
);

    
    // -------------------------------------------------------------------------
    // Lighting Controller Instantiation
    // -------------------------------------------------------------------------
    // brightness_level = 15 (max) → đèn sáng mạnh
    wire [7:0] brightness_level = 8'd2;    
    // base_rgb đại diện cho nhiệt độ 25-45°C (màu lạnh → nóng)
    // Ở đây chọn màu xanh lạnh để test: R=0, G=0, B=255 → {R,G,B}
    // wire [23:0] base_rgb = {8'd0, 8'd0, 8'd255};
    // Ví dụ: 34°C → Yellow-Green (128,255,0)
    wire [23:0] base_rgb = {8'd0, 8'd225, 8'd128};
    // Tự động generate pattern mỗi frame và gửi xuống ws2812_chain → ws2812_pixel_driver
    lighting_controller #(.NUM_LEDS(64)) lighting_ctrl_inst (
        .clk(clk),
        .rst(rst),
        .brightness_level(brightness_level),
        .base_rgb(base_rgb),
        .data_out(ws2812_dout)
    );

endmodule
