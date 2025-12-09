module lighting_controller #(
    parameter integer NUM_LEDS = 64    // ma trận 8x8
)(
    input  wire                   clk,
    input  wire                   rst,

    // 0..15: điều chỉnh độ sáng tổng
    input  wire [7:0]             brightness_level,

    // Màu cơ bản theo nhiệt độ:
    // Ví dụ:
    // 25°C: {  0,  80, 255}
    // 28°C: {  0, 128, 255}
    // 31°C: {  0, 255, 128}
    // 34°C: {128, 255,   0}
    // 37°C: {255, 255,   0}
    // 40°C: {255, 160,   0}
    // 45°C: {255,   0,   0}
    // format: {R[23:16], G[15:8], B[7:0]}
    input  wire [23:0]            base_rgb,

    // Dữ liệu ra dải WS2812
    output wire                   data_out
);



    // =====================================================================
    // 1. KẾT NỐI NỘI BỘ VỚI ws2812_chain
    // =====================================================================

    reg                    ws_start = 1'b0;
    reg [NUM_LEDS*24-1:0]  led_data = {NUM_LEDS*24{1'b0}};
    wire                   chain_done;

    ws2812_chain #(.NUM_LEDS(NUM_LEDS)) u_chain (
        .clk      (clk),
        .rst      (rst),
        .start    (ws_start),
        .led_data (led_data),
        .data_out (data_out),
        .done     (chain_done)
    );
    
    
    // chống glitch khi system_controller đổi base_rgb/brightness_level giữa frame
    reg [23:0] base_rgb_reg;
    reg [7:0]  brightness_reg;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            base_rgb_reg  <= 24'd0;
            brightness_reg <= 8'd0;
        end else if (ws_start) begin
            base_rgb_reg   <= base_rgb;
            brightness_reg <= brightness_level;
        end
    end

    // =====================================================================
    // 2. FSM GỬI FRAME - mỗi frame là 1 "ảnh" của sóng
    // =====================================================================

    localparam ST_WAIT_DELAY = 2'd0;
    localparam ST_WAIT_DONE  = 2'd1;
    localparam integer MAX_RADIUS2 = 32;

    reg [1:0]  state      = ST_WAIT_DELAY;
    reg [31:0] delay_cnt  = 0;

    // Thời gian giữa 2 frame → tốc độ chạy sóng
    localparam integer FRAME_DELAY = 2_000_000;   // ~16ms @125MHz

    // Pha của sóng (bán kính vòng sáng) - tăng dần để sóng lan ra
    reg [7:0] wave_phase = 0;
    localparam integer PHASE_STEP  = 1;           // tốc độ lan sóng

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ws_start   <= 1'b0;
            state      <= ST_WAIT_DELAY;
            delay_cnt  <= 32'd0;
            wave_phase <= 8'd0;
        end else begin
            case (state)
                ST_WAIT_DELAY: begin
                    ws_start <= 1'b0;
                    // Trong ST_WAIT_DELAY khi hết delay:
                    if (delay_cnt < FRAME_DELAY) begin
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        delay_cnt <= 32'd0;
                        // thay vì: wave_phase <= wave_phase + PHASE_STEP;
                        if (wave_phase >= MAX_RADIUS2)
                            wave_phase <= 8'd0;
                        else
                            wave_phase <= wave_phase + PHASE_STEP;
                        ws_start  <= 1'b1;
                        state     <= ST_WAIT_DONE;
                    end 
                end

                ST_WAIT_DONE: begin
                    ws_start <= 1'b0;
                    if (chain_done)
                        state <= ST_WAIT_DELAY;
                end
            endcase
        end
    end

    // =====================================================================
    // 3. PATTERN SÓNG VÒNG CUNG LAN RA
    //
    //  Ý tưởng:
    //    - LED nằm trên ma trận 8x8: i → (x,y)
    //    - Tính "bán kính" từ tâm ma trận đến (x,y)
    //    - Sóng là 1 vòng sáng mỏng, lan từ tâm ra ngoài:
    //      + Nếu |radius - wave_phase| nhỏ → LED sáng
    //      + Ngược lại → LED tắt (hoặc rất tối)
    //
    //  Cảm giác: 1 vòng sáng tròn lan từ giữa ra viền, cứ lặp lại.
    // =====================================================================

    localparam integer WIDTH  = 8;
    localparam integer HEIGHT = 8;

    // Tâm ma trận: (3.5, 3.5) - ta xấp xỉ bằng (3,3) cho đơn giản integer
    localparam integer CX = 3;
    localparam integer CY = 3;

    // Tối đa radius^2 ≈ (dx^2 + dy^2) với dx,dy∈[0..4] → 4^2+4^2=32
    // Ta cho WAVE_RADIUS_PERIOD > max radius^2 để sóng "cuộn lại"
    localparam integer WAVE_RADIUS_PERIOD = 40;

    // Độ dày của vòng sáng: càng lớn thì vòng càng dày
    localparam integer RING_WIDTH = 3;

    // Brightness level dùng 4 bit thấp 0..15
    wire [3:0] lvl = brightness_level[3:0];

    // Tách base_rgb thành R,G,B
    wire [7:0] base_r = base_rgb[23:16];
    wire [7:0] base_g = base_rgb[15:8];
    wire [7:0] base_b = base_rgb[7:0];

    integer i;
    integer x, y;
    integer dx, dy;
    integer radius2;
    integer center_phase;
    integer diff;
    
    reg [7:0]  wave_factor;   // 0..15 (0=tắt, 15=sáng max theo brightness)
    reg [7:0]  level_scale;   // 0..15
    reg [7:0]  mult;
    
    reg [11:0] r_tmp, g_tmp, b_tmp;
    reg [7:0]  r_scaled, g_scaled, b_scaled;

    always @* begin
        for (i = 0; i < NUM_LEDS; i = i + 1) begin
            // Map index i → (x,y) trong ma trận 8x8 (row-major)
            x = i % WIDTH;
            y = i / WIDTH;

            // Khoảng cách từ tâm (CX,CY)
            dx = x - CX;
            dy = y - CY;
            if (dx < 0) dx = -dx;
            if (dy < 0) dy = -dy;

            // radius2 ~ độ lớn của bán kính (xấp xỉ)
            radius2 = dx*dx + dy*dy;  // 0..32

            // Tâm sóng hiện tại (theo phase), cuộn trong WAVE_RADIUS_PERIOD
            center_phase = wave_phase;  // wave_phase đã luôn 0..32
            

            // Độ lệch giữa vị trí LED và tâm sóng
            diff = radius2 - center_phase;
            if (diff < 0) diff = -diff;

            // Nếu LED nằm gần tâm sóng (diff nhỏ) → sáng, ngược lại → tối
            if (diff <= RING_WIDTH)
                wave_factor = 8'd15;       // LED "trúng" vòng sóng
            else
                wave_factor = 8'd0;        // LED ngoài vòng → tắt

            // Kết hợp brightness tổng 0..15 với wave_factor 0..15
            // --- Kết hợp brightness tổng (lvl) với sóng ---
            if (lvl == 0 || wave_factor == 0) begin
                level_scale = 8'd0;
            end else begin
                mult        = lvl * wave_factor;    // 0..225
                level_scale = mult >> 4;            // 0..14

                // tránh trường hợp lvl nhỏ bị rơi về 0
                if (level_scale == 0)
                    level_scale = 8'd1;
            end

            // --- Scale base_rgb theo level_scale (0..15) ---
            r_tmp    = base_r * level_scale;   // 8x4=12 bit
            g_tmp    = base_g * level_scale;
            b_tmp    = base_b * level_scale;

            // Giảm thêm cho đỡ chói: /32
            r_scaled = r_tmp[11:5];
            g_scaled = g_tmp[11:5];
            b_scaled = b_tmp[11:5];

            // WS2812 order = GRB
            // ws2812_chain đọc LED[0] từ MSB → đảo index
            led_data[(NUM_LEDS-1-i)*24 +: 24] = {g_scaled, r_scaled, b_scaled};
        end
    end

endmodule
