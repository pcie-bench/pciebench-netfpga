#
# Copyright (c) 2016
# All rights reserved.
#
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

# Set the paths
set current_dir "[file normalize "."]"
set project_dir "[file normalize "./project"]"
set src_dir "[file normalize "./src"]"
set project_name "dmagen3"



# Create the project and specify the board
create_project $project_name $project_dir/$project_name -part xc7vx690tffg1761-2


#### CREATE IPs #### 
# AXI GPIO
#create_ip -name axi_gpio -vendor xilinx.com -library ip -version 2.0 -module_name axi_gpio_0
create_ip -name axi_gpio -vendor xilinx.com -library ip -module_name axi_gpio_0
set_property -dict [list CONFIG.C_GPIO_WIDTH {2}] [get_ips axi_gpio_0]
create_ip_run [get_files -of_objects [get_fileset sources_1] $project_dir/$project_name/$project_name.srcs/sources_1/ip/axi_gpio_0/axi_gpio_0.xci]

# AXI Broadcaster
#create_ip -name axis_broadcaster -vendor xilinx.com -library ip -version 1.1 -module_name axis_broadcaster_0
create_ip -name axis_broadcaster -vendor xilinx.com -library ip -module_name axis_broadcaster_0
set_property -dict [list CONFIG.M_TDATA_NUM_BYTES {32} CONFIG.S_TDATA_NUM_BYTES {32} CONFIG.M_TUSER_WIDTH {85} CONFIG.S_TUSER_WIDTH {85} CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.M00_TDATA_REMAP {tdata[255:0]} CONFIG.M01_TDATA_REMAP {tdata[255:0]} CONFIG.M00_TUSER_REMAP {tuser[84:0]} CONFIG.M01_TUSER_REMAP {tuser[84:0]}] [get_ips axis_broadcaster_0]
create_ip_run [get_files -of_objects [get_fileset sources_1] $project_dir/$project_name/$project_name.srcs/sources_1/ip/axis_broadcaster_0/axis_broadcaster_0.xci]

# AXIS  axis_fifo_2clk_32d_12u
#create_ip -name fifo_generator -vendor xilinx.com -library ip -version 12.0 -module_name axis_fifo_2clk_32d_12u
create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name axis_fifo_2clk_32d_12u
set_property -dict [list CONFIG.INTERFACE_TYPE {AXI_STREAM} CONFIG.Clock_Type_AXI {Independent_Clock} CONFIG.TUSER_WIDTH {12} CONFIG.Input_Depth_axis {16} CONFIG.Reset_Type {Asynchronous_Reset} CONFIG.Full_Flags_Reset_Value {1} CONFIG.FIFO_Implementation_wach {Independent_Clocks_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_wach {15} CONFIG.Empty_Threshold_Assert_Value_wach {13} CONFIG.FIFO_Implementation_wdch {Independent_Clocks_Block_RAM} CONFIG.Empty_Threshold_Assert_Value_wdch {1021} CONFIG.FIFO_Implementation_wrch {Independent_Clocks_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_wrch {15} CONFIG.Empty_Threshold_Assert_Value_wrch {13} CONFIG.FIFO_Implementation_rach {Independent_Clocks_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_rach {15} CONFIG.Empty_Threshold_Assert_Value_rach {13} CONFIG.FIFO_Implementation_rdch {Independent_Clocks_Block_RAM} CONFIG.Empty_Threshold_Assert_Value_rdch {1021} CONFIG.FIFO_Implementation_axis {Independent_Clocks_Block_RAM} CONFIG.Full_Threshold_Assert_Value_axis {15} CONFIG.Empty_Threshold_Assert_Value_axis {13}] [get_ips axis_fifo_2clk_32d_12u]
set_property -dict [list CONFIG.TDATA_NUM_BYTES {4} CONFIG.Input_Depth_axis {16} CONFIG.TSTRB_WIDTH {4} CONFIG.TKEEP_WIDTH {4} CONFIG.Full_Threshold_Assert_Value_axis {15} CONFIG.Empty_Threshold_Assert_Value_axis {13}] [get_ips axis_fifo_2clk_32d_12u]
create_ip_run [get_files -of_objects [get_fileset sources_1] $project_dir/$project_name/$project_name.srcs/sources_1/ip/axis_fifo_2clk_32d_12u/axis_fifo_2clk_32d_12u.xci]

# axis_switch_0
#create_ip -name axis_switch -vendor xilinx.com -library ip -version 1.1 -module_name axis_switch_0
create_ip -name axis_switch -vendor xilinx.com -library ip -module_name axis_switch_0
set_property -dict [list CONFIG.TDATA_NUM_BYTES {32} CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.TUSER_WIDTH {33} CONFIG.ARB_ON_TLAST {1}] [get_ips axis_switch_0]
create_ip_run [get_files -of_objects [get_fileset sources_1] $project_dir/$project_name/$project_name.srcs/sources_1/ip/axis_switch_0/axis_switch_0.xci]

# blk_mem_descriptor
#create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.2 -module_name blk_mem_descriptor
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name blk_mem_descriptor
set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM} CONFIG.Use_Byte_Write_Enable {true} CONFIG.Byte_Size {8} CONFIG.Write_Width_A {64} CONFIG.Write_Depth_A {1024} CONFIG.Operating_Mode_A {WRITE_FIRST} CONFIG.Read_Width_A {64} CONFIG.Write_Width_B {64} CONFIG.Read_Width_B {64} CONFIG.Enable_B {Use_ENB_Pin} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Register_PortB_Output_of_Memory_Primitives {true} CONFIG.Port_B_Clock {100} CONFIG.Port_B_Enable_Rate {100}] [get_ips blk_mem_descriptor]
create_ip_run [get_files -of_objects [get_fileset sources_1] $project_dir/$project_name/$project_name.srcs/sources_1/ip/blk_mem_descriptor/blk_mem_descriptor.xci]

# pcie3_7x_0
#create_ip -name pcie3_7x -vendor xilinx.com -library ip -version 3.0 -module_name pcie3_7x_0
create_ip -name pcie3_7x -vendor xilinx.com -library ip -module_name pcie3_7x_0
set_property -dict [list CONFIG.xlnx_ref_board {VC709} CONFIG.PL_LINK_CAP_MAX_LINK_WIDTH {X8} CONFIG.PL_LINK_CAP_MAX_LINK_SPEED {8.0_GT/s} CONFIG.axisten_if_enable_client_tag {false} CONFIG.AXISTEN_IF_RC_STRADDLE {false} CONFIG.SRIOV_CAP_ENABLE {false} CONFIG.pf0_msi_enabled {false} CONFIG.pf0_bar0_64bit {true} CONFIG.pf0_bar0_scale {Megabytes} CONFIG.pf0_bar0_size {16} CONFIG.pf0_bar2_enabled {true} CONFIG.pf0_bar2_64bit {true} CONFIG.pf0_bar2_scale {Megabytes} CONFIG.pf0_bar2_size {4} CONFIG.pf0_bar4_enabled {true} CONFIG.pf0_bar4_64bit {true} CONFIG.pf0_bar4_scale {Megabytes} CONFIG.pf0_bar4_size {4} CONFIG.pf0_sriov_bar0_scale {Megabytes} CONFIG.PF0_INTERRUPT_PIN {NONE} CONFIG.pf0_msix_enabled {false}  CONFIG.mode_selection {Advanced} CONFIG.en_msi_per_vec_masking {false} CONFIG.axisten_freq {250} CONFIG.pcie_blk_locn {X0Y1} CONFIG.gen_x0y0 {false} CONFIG.gen_x0y1 {true} CONFIG.axisten_if_width {256_bit} CONFIG.PF0_DEVICE_ID {7038} CONFIG.PF1_DEVICE_ID {7011} CONFIG.pf0_bar2_type {Memory} CONFIG.pf0_bar4_type {Memory} CONFIG.pf0_ari_enabled {true} CONFIG.SRIOV_CAP_ENABLE_EXT {false}] [get_ips pcie3_7x_0]
create_ip_run [get_files -of_objects [get_fileset sources_1] $project_dir/$project_name/$project_name.srcs/sources_1/ip/pcie3_7x_0/pcie3_7x_0.xci]


# user_fifo
#create_ip -name fifo_generator -vendor xilinx.com -library ip -version 12.0 -module_name user_fifo
create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name user_fifo
set_property -dict [list CONFIG.INTERFACE_TYPE {AXI_STREAM} CONFIG.TDATA_NUM_BYTES {32} CONFIG.TUSER_WIDTH {0} CONFIG.Enable_TLAST {true} CONFIG.HAS_TKEEP {true} CONFIG.TSTRB_WIDTH {32} CONFIG.TKEEP_WIDTH {32} CONFIG.FIFO_Implementation_wach {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_wach {15} CONFIG.Empty_Threshold_Assert_Value_wach {14} CONFIG.FIFO_Implementation_wrch {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_wrch {15} CONFIG.Empty_Threshold_Assert_Value_wrch {14} CONFIG.FIFO_Implementation_rach {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_rach {15} CONFIG.Empty_Threshold_Assert_Value_rach {14}] [get_ips user_fifo]
create_ip_run [get_files -of_objects [get_fileset sources_1] $project_dir/$project_name/$project_name.srcs/sources_1/ip/user_fifo/user_fifo.xci]


#### Add files. HDL #### 

add_files -fileset constrs_1 -norecurse $current_dir/source/constr/pcie_benchmark_sume.xdc
add_files $current_dir/source/hdl

set_property top pcie_benchmark [current_fileset]

#### Syhthesize IP files #### 

launch_run -jobs 4 axi_gpio_0_synth_1
wait_on_run axi_gpio_0_synth_1
launch_run -jobs 4 axis_broadcaster_0_synth_1
wait_on_run axis_broadcaster_0_synth_1
launch_run -jobs 4 axis_fifo_2clk_32d_12u_synth_1
wait_on_run axis_fifo_2clk_32d_12u_synth_1
launch_run -jobs 4 axis_switch_0_synth_1
wait_on_run axis_switch_0_synth_1
launch_run -jobs 4 blk_mem_descriptor_synth_1
wait_on_run blk_mem_descriptor_synth_1
launch_run -jobs 4 pcie3_7x_0_synth_1
wait_on_run pcie3_7x_0_synth_1
launch_run -jobs 4 user_fifo_synth_1
wait_on_run user_fifo_synth_1

#set_property strategy Performance_Explore [get_runs impl_1]
set_property strategy Performance_Explore [get_runs impl_1]
reset_run impl_1


close_project
