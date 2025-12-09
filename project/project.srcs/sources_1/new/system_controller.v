module system_controller (
    input  wire        clk,
    input  wire        rst,

    // --- Sensor data (từ i2c_subsystem) ---
    input  wire [15:0] lux_value,
    input  wire [15:0] temp_value,

    // --- Điều khiển LCD ---
	input  wire lcd_update_done,
	output reg  lcd_update_req,
	output reg [127:0] line1_text,
	output reg [127:0] line2_text,

    // --- Thông tin cho lighting_controller ---
    // brightness_level: mức sáng tổng thể (0..255)
    // base_rgb: màu cơ bản (pattern sẽ dựa trên màu này)
	output reg [7:0]   brightness_level,
    output reg [23:0]  base_rgb
);
    // TODO: xử lý bên trong sau:
    //  - từ lux/temp -> brightness_level & base_rgb
    //  - từ lux/temp -> line1_text/line2_text -> lcd_update_req

	//xac dinh co gtri moi de update lcd
	reg [15:0] lux_prev, temp_prev;
	wire lux_change  = (lux_value  != lux_prev);
	wire temp_change = (temp_value != temp_prev);
	
	//brightness mapping (0-15)
	always @(posedge clk or posedge rst) begin
        if (rst) begin
            lux_prev <= 1'b0;
            brightness_level <= 1'b0;
        end 
		else begin
            lux_prev <= lux_value;
            brightness_level <= lux_value[15:12];   // scale 0–15
        end
    end
	
	//temperature color mapping (25 - 45°C)
	//Temperature → 0.125°C / bit
    //temp_value >> 3 = /8 (0.125*8 = 1°C)
	wire [7:0] temp_C = temp_value >> 3; 
	wire [7:0] clamp  = (temp_C < 25) ? 25 : (temp_C > 45) ? 45 : temp_C;
	
	always @(*) begin
		case(clamp)
			25, 26, 27: base_rgb = 24'h0050FF; //Cold blue
			28, 29, 30: base_rgb = 24'h0080FF; //Light blue
			31, 32, 33: base_rgb = 24'h00FF80; //Cyan green
			34, 35, 36: base_rgb = 24'h80FF00; //Yello green
			37, 38, 39: base_rgb = 24'hFFFF00; //Yello
			40, 41, 42: base_rgb = 24'hFFA000; //Orange
			43, 44, 45: base_rgb = 24'hFF0000; //Red
			default:    base_rgb = 24'h000000; 
		endcase
	end
	
	//hien thi lcd
	function [7:0] to_ascii;
		input [3:0] n;
		to_ascii = "0" + n;
	endfunction
	
	wire [3:0] lux_t  = (lux_value / 10);
	wire [3:0] lux_u  = (lux_value % 10);
	wire [3:0] temp_t = (temp_C / 10);
	wire [3:0] temp_u = (temp_C % 10);
	
	always @(*) begin
		line1_text = {"L","U","X",":"," ",to_ascii(lux_t),to_ascii(lux_u),
						" "," "," "," "," "," "," "," "," "};
	end
	
	always @(*) begin
		line2_text = {"T","E","M","P",":"," ",to_ascii(temp_t),to_ascii(temp_u),
						" ","C"," "," "," "," "," "," "};
	end
	
	
	//update LCD
	reg [1:0] state, next_state;
	parameter IDLE      = 2'b00;
	parameter SENT_REQ  = 2'b01;
	parameter WAIT_DONE = 2'b10;
	
	always @(posedge clk or posedge rst) begin
		state <= (rst) ? IDLE : next_state;
	end
	
	always @(*) begin
		case(state)
			IDLE: 
				next_state = (lux_change || temp_change) ? SENT_REQ : IDLE;
			SENT_REQ: 
				next_state = WAIT_DONE;
			WAIT_DONE: 
				next_state = (lcd_update_done) ? IDLE : WAIT_DONE;
			default:
				next_state = IDLE;
		endcase
	end
	
	always @(posedge clk or posedge rst) begin
		if(rst) 
			lcd_update_req <= 1'b0;
		else begin
			case(state)
				IDLE: 
					lcd_update_req <= 1'b0;
				SENT_REQ : 
					lcd_update_req <= 1'b1;
				WAIT_DONE : 
					lcd_update_req <= 1'b0;
			endcase
		end
	end
	

endmodule
