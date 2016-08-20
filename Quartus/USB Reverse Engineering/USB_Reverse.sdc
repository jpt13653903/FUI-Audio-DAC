create_clock -name Clk -period 20 [get_ports {Clk}]

derive_pll_clocks -create_base_clocks -use_net_name
derive_clock_uncertainty
#-------------------------------------------------------------------------------

set_input_delay  -clock altera_reserved_tck -clock_fall 3 \
                 [get_ports altera_reserved_tdi]
set_input_delay  -clock altera_reserved_tck -clock_fall 3 \
                 [get_ports altera_reserved_tms]
set_output_delay -clock altera_reserved_tck -clock_fall 3 \
                 [get_ports altera_reserved_tdo]
#-------------------------------------------------------------------------------

set_false_path -from [get_ports *] -to *
set_false_path -from * -to [get_ports *]
#-------------------------------------------------------------------------------

