module lcd_controller (
    input  wire       clk,
    input  wire       rst_n,

    // Yêu cầu cập nhật từ System Controller
    input  wire       update_req,      // 1 pulse: cập nhật lại LCD
    output wire       update_done,     // Hoàn thành

    // Nội dung 2 dòng (16 ký tự/dòng, mỗi ký tự 8 bit)
    input  wire [16*8-1:0] line1_text, // [127:0]
    input  wire [16*8-1:0] line2_text,

    // Giao tiếp xuống lcd_byte_send
    output wire       lbyte_start,
    output wire [7:0] lbyte_data,
    output wire       lbyte_rs,        // 0=cmd, 1=data
    input  wire       lbyte_busy,
    input  wire       lbyte_done
);
endmodule
