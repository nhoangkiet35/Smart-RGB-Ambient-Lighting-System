module lighting_controller #(
    parameter integer NUM_LEDS = 16
)(
    input  wire                     clk,
    input  wire                     rst,

    // Đầu vào từ system_controller
    input  wire [7:0]               brightness_level,  // 0..255
    input  wire [23:0]              base_rgb,          // {R[23:16], G[15:8], B[7:0]}

    // Kết quả: dữ liệu màu cho dải WS2812
    output wire                     ws_start,          // yêu cầu ws2812_chain gửi
    output wire [NUM_LEDS*24-1:0]   led_data           // 24 bit / LED
);
    // TODO: bên trong bạn sẽ:
    //  - dùng brightness_level & base_rgb để tạo pattern, gradient, v.v.
    //  - set ws_start khi đã sẵn sàng dữ liệu mới
endmodule
