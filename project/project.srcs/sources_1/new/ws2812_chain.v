module ws2812_chain #(
    parameter integer NUM_LEDS = 16
)(
    input  wire                     clk,       // 125 MHz
    input  wire                     rst_n,

    input  wire                     start,     // Bắt đầu gửi cả chuỗi
    input  wire [NUM_LEDS*24-1:0]   led_data,  // Màu của toàn bộ dải

    output wire                     data_out,  // Ra thực tế tới dải LED
    output wire                     done       // Hoàn thành gửi toàn bộ chuỗi
);
    reg [23:0] current_color;
    reg [7:0] led_index = 0;
    reg driver_start = 0;
    wire driver_done;

    // WS2812 driver
    ws2812_driver driver (
        .clk(clk),
        .rst_n(rst_n),
        .start(driver_start),
        .color(current_color),
        .data_out(data_out),
        .done(driver_done)
    );
endmodule
