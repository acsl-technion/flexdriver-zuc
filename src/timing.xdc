########################################
##  PCIe TIMING CONSTRAINTS           ##
########################################

create_clock   -name pcie_clk -period 10    [get_ports pcie_clk_p]

set_false_path -from                        [get_ports pcie_perst]

