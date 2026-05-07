# Push Buttons
set_property    PACKAGE_PIN     M15         [get_ports rstn_push]
set_property    IOSTANDARD      LVCMOS33    [get_ports rstn_push]

# LEDs
set_property    PACKAGE_PIN     J14         [get_ports rstn_led]
set_property    IOSTANDARD      LVCMOS33    [get_ports rstn_led]

set_property    PACKAGE_PIN     K14         [get_ports start_led]
set_property    IOSTANDARD      LVCMOS33    [get_ports start_led]

# UART
set_property    PACKAGE_PIN     U12         [get_ports uart_rx]
set_property    IOSTANDARD      LVCMOS33    [get_ports uart_rx]

set_property    PACKAGE_PIN     R14         [get_ports uart_tx]
set_property    IOSTANDARD      LVCMOS33    [get_ports uart_tx]

# Timing Exceptions
set_false_path  -from           [get_ports rstn_push]
set_false_path  -to             [get_ports {rstn_led start_led}]
set_false_path  -from           [get_ports uart_rx]
set_false_path  -to             [get_ports uart_tx]
