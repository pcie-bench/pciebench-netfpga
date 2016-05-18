# Copyright (c) 2016
# All rights reserved.
#
# as part of the DARPA MRC research programme.
#
# @NETFPGA_LICENSE_HEADER_START@
#
# Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  NetFPGA licenses this
# file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at:
#
#   http://www.netfpga-cic.org
#
# Unless required by applicable law or agreed to in writing, Work distributed
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations under the License.
#
# @NETFPGA_LICENSE_HEADER_END@
#

create_clock -period 10.000 -name sys_clk_p -waveform {0.000 5.000} [get_ports pcie_refclk_p]


# set_false_path -from [get_clocks sys_clk_p] -to [get_clocks userclk2]
# create_generated_clock -name clk_125mhz_Gen -source [get_pins pcie3_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I0] -divide_by 1 -add -master_clock clk_125mhz [get_pins pcie3_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O]
# create_generated_clock -name clk_250mhz_Gen -source [get_pins pcie3_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1] -divide_by 1 -add -master_clock clk_250mhz [get_pins pcie3_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O]
# set_clock_groups -logically_exclusive -group [get_clocks -include_generated_clocks clk_125mhz_Gen] -group [get_clocks -include_generated_clocks clk_250mhz_Gen]

set_property PACKAGE_PIN AV35 [get_ports pcie_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports pcie_rst_n]
set_property PULLUP true [get_ports pcie_rst_n]

#
#
# SYS clock 100 MHz (input) signal. The sys_clk_p and sys_clk_n
# signals are the PCI Express reference clock. Virtex-7 GT
# Transceiver architecture requires the use of a dedicated clock
# resources (FPGA input pins) associated with each GT Transceiver.
# To use these pins an IBUFDS primitive (refclk_ibuf) is
# instantiated in user's design.
# Please refer to the Virtex-7 GT Transceiver User Guide
# (UG) for guidelines regarding clock resource selection.
#
set_property LOC IBUFDS_GTE2_X1Y11 [get_cells pcie_ep_wrapper_i/refclk_ibuf]

set_property PACKAGE_PIN AM39 [get_ports {led[0]}]
set_property PACKAGE_PIN AN39 [get_ports {led[1]}]


set_property IOSTANDARD LVCMOS18 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[1]}]



set_property PACKAGE_PIN AV39 [get_ports {button[0]}]
set_property PACKAGE_PIN AU38 [get_ports {button[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {button[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {button[1]}]




set_false_path -to [get_pins pcie_ep_wrapper_i/pcie3_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S*]


########################################################## EOC

