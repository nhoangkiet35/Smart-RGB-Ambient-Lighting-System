## This file is a general .xdc for the PYNQ-Z2 board 
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock signal 125 MHz

set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L13P_T2_MRCC_35 Sch=sysclk
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

##Buttons

set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { rst }]; #IO_L4P_T0_35 Sch=btn[0]

##PmodB

set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { ws2812_dout }]; #IO_L1N_T0_34 Sch=jb_n[2]

## Arduino I2C

set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { i2c_scl }]; #IO_L24N_T3_34 Sch=ar_scl
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { i2c_sda }]; #IO_L24P_T3_34 Sch=ar_sda

