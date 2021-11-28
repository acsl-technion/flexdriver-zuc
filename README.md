# FlexDriver ZUC cipher example AFU

This repository contains an example AFU for FlexDriver, demonstrated in the paper *FlexDriver: A Network Driver for Your Accelerator*.
The example accelerator encrypts/decrypts and authenticates messages using the 128-EEA3 / 128-EIA3 standards.

## Build instructions

To build, you will need to acquire FlexDriver IP (`src/flc.dcp`) from NVIDIA
Networking, and use Xilinx Vivado 2019.2 to build.

    vivado -source run_project.tcl

## References

 * [Specifications of the 3GPP Confidentiality and Integrity Algorithms 128-EAE3 & 128-EIA3 -- ZUC Specification](https://www.gsma.com/aboutus/wp-content/uploads/2014/12/eea3eia3zucv16.pdf)
