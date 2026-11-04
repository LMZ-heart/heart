# 1. 系统时钟
set_property PACKAGE_PIN P17 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin [get_ports clk]

# 2. 复位按键
set_property PACKAGE_PIN P15 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

# 3. XADC 模拟输入 (通道11，对应 J5‑7 / J5‑8)
# 切记：模拟引脚绝对不能加 IOSTANDARD！
set_property PACKAGE_PIN B18 [get_ports vauxp11_in]
set_property PACKAGE_PIN A18 [get_ports vauxn11_in]

# 4. 串口输出
set_property PACKAGE_PIN T4 [get_ports uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd]

# 5. 兜底配置
set_property BITSTREAM.General.UnconstrainedPins {Allow} [current_design]
