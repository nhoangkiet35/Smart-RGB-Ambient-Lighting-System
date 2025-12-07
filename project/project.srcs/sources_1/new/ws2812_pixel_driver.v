module ws2812_pixel_driver (
    input  wire       clk,      // 125 MHz
    input  wire       rst,
    input  wire       start,    // Bắt đầu gửi 24 bit
    input  wire [23:0] color,   // Dữ liệu màu cho 1 LED (GRB/RGB)

    output wire       data_out, // Tín hiệu tới dải LED
    output wire       done      // Hoàn thành gửi 1 LED
);
endmodule
