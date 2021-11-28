########################################
##  PCIe PINOUT CONSTRAINTS           ##
########################################

set_property PACKAGE_PIN     AB27           [get_ports pcie_clk_p]
set_property PACKAGE_PIN     AB28           [get_ports pcie_clk_n]

set_property PACKAGE_PIN     F2             [get_ports pcie_perst]
set_property IOSTANDARD      LVCMOS33       [get_ports pcie_perst]
set_property PULLUP          true           [get_ports pcie_perst]

set_property PACKAGE_PIN     AF31           [get_ports {pcie_tx_p[0]}]
set_property PACKAGE_PIN     AF32           [get_ports {pcie_tx_n[0]}]
set_property PACKAGE_PIN     AH36           [get_ports {pcie_rx_p[0]}]
set_property PACKAGE_PIN     AH37           [get_ports {pcie_rx_n[0]}]

set_property PACKAGE_PIN     AE33           [get_ports {pcie_tx_p[1]}]
set_property PACKAGE_PIN     AE34           [get_ports {pcie_tx_n[1]}]
set_property PACKAGE_PIN     AG38           [get_ports {pcie_rx_p[1]}]
set_property PACKAGE_PIN     AG39           [get_ports {pcie_rx_n[1]}]

set_property PACKAGE_PIN     AD31           [get_ports {pcie_tx_p[2]}]
set_property PACKAGE_PIN     AD32           [get_ports {pcie_tx_n[2]}]
set_property PACKAGE_PIN     AF36           [get_ports {pcie_rx_p[2]}]
set_property PACKAGE_PIN     AF37           [get_ports {pcie_rx_n[2]}]

set_property PACKAGE_PIN     AC33           [get_ports {pcie_tx_p[3]}]
set_property PACKAGE_PIN     AC34           [get_ports {pcie_tx_n[3]}]
set_property PACKAGE_PIN     AE38           [get_ports {pcie_rx_p[3]}]
set_property PACKAGE_PIN     AE39           [get_ports {pcie_rx_n[3]}]

set_property PACKAGE_PIN     AB31           [get_ports {pcie_tx_p[4]}]
set_property PACKAGE_PIN     AB32           [get_ports {pcie_tx_n[4]}]
set_property PACKAGE_PIN     AD36           [get_ports {pcie_rx_p[4]}]
set_property PACKAGE_PIN     AD37           [get_ports {pcie_rx_n[4]}]

set_property PACKAGE_PIN     AA33           [get_ports {pcie_tx_p[5]}]
set_property PACKAGE_PIN     AA34           [get_ports {pcie_tx_n[5]}]
set_property PACKAGE_PIN     AC38           [get_ports {pcie_rx_p[5]}]
set_property PACKAGE_PIN     AC39           [get_ports {pcie_rx_n[5]}]

set_property PACKAGE_PIN     Y31            [get_ports {pcie_tx_p[6]}]
set_property PACKAGE_PIN     Y32            [get_ports {pcie_tx_n[6]}]
set_property PACKAGE_PIN     AB36           [get_ports {pcie_rx_p[6]}]
set_property PACKAGE_PIN     AB37           [get_ports {pcie_rx_n[6]}]

set_property PACKAGE_PIN     W33            [get_ports {pcie_tx_p[7]}]
set_property PACKAGE_PIN     W34            [get_ports {pcie_tx_n[7]}]
set_property PACKAGE_PIN     AA38           [get_ports {pcie_rx_p[7]}]
set_property PACKAGE_PIN     AA39           [get_ports {pcie_rx_n[7]}]
