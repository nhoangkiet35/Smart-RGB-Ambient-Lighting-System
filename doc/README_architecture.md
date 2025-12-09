```
SmartRGB_AmbientLighting/
├── rtl/
│   ├── top/
│   │   └── top.v                         // Top-level FPGA
│   │
│   ├── system/
│   │   └── system_controller.v           // Điều khiển logic tổng
│   │
│   ├── bus_i2c/
│   │   ├── i2c_master.v                  // I2C master
│   │   ├── i2c_arbiter.v                 // Arbiter chia bus cho BH1750/LM75/LCD
│   │   └── i2c_defs.vh                   // (optional) define chung: addr, cmd...
│   │
│   ├── sensors/
│   │   ├── bh1750_client.v               // Giao tiếp BH1750 (lux_value)
│   │   └── lm75_client.v                 // Giao tiếp LM75 (temp_value)
│   │
│   ├── display_lcd/
│   │   ├── lcd_controller.v              // Nhận line1/line2, sinh lbyte_*
│   │   ├── lcd_byte_send.v               // Gửi 1 byte qua PCF8574 + I2C
│   │   └── lcd_char_mem.v                // (nếu có) bộ nhớ ký tự
│   │
│   ├── led_ws2812/
│   │   ├── ws2812_chain.v                // Chuỗi LED WS2812, data_out, done
│   │   └── lighting_controller.v         // Nhận brightness_level + base_rgb
│   │
│   └── common/
│       ├── clk_reset_sync.v              // (optional) đồng bộ reset, chia clock
│       └── util_pkg.vh                   // (optional) hàm, macro dùng chung
│
├── sim/
│   ├── tb_i2c_master.v
│   ├── tb_i2c_arbiter.v
│   ├── tb_bh1750_client.v
│   ├── tb_lm75_client.v
│   ├── tb_lcd_controller.v
│   ├── tb_ws2812_chain.v
│   └── tb_top.v                          // Test toàn hệ thống
│
├── constr/
│   └── top.xdc                           // Pin clk, rst, SDA, SCL, WS2812
│
├── doc/
│   ├── overview_design.pdf               // Sơ đồ block (file bạn vừa gửi)
│   └── README_architecture.md            // Mô tả kiến trúc, luồng dữ liệu
│
├── scripts/
│   ├── run_vivado.tcl                    // Script build/synth
│   └── run_sim.do                        // Script chạy simulator (ModelSim/Questa)
│
└── README.md                             // Mô tả ngắn gọn dự án

```
