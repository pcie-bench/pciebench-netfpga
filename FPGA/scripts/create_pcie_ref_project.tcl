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
set project_dir "[file normalize "/tmp/tmp_project"]"
set project_name "tmp_project"


# Create the project and specify the board
create_project $project_name $project_dir/$project_name -part xc7vx690tffg1761-2

create_ip -name pcie3_7x -vendor xilinx.com -library ip -module_name pcie3_7x_0
set_property -dict [list CONFIG.xlnx_ref_board {VC709} CONFIG.PL_LINK_CAP_MAX_LINK_WIDTH {X8} CONFIG.PL_LINK_CAP_MAX_LINK_SPEED {8.0_GT/s} CONFIG.axisten_if_enable_client_tag {false} CONFIG.AXISTEN_IF_RC_STRADDLE {false} CONFIG.SRIOV_CAP_ENABLE {false} CONFIG.pf0_msi_enabled {false} CONFIG.pf0_bar0_64bit {true} CONFIG.pf0_bar0_scale {Megabytes} CONFIG.pf0_bar0_size {16} CONFIG.pf0_bar2_enabled {true} CONFIG.pf0_bar2_64bit {true} CONFIG.pf0_bar2_scale {Megabytes} CONFIG.pf0_bar2_size {4} CONFIG.pf0_bar4_enabled {true} CONFIG.pf0_bar4_64bit {true} CONFIG.pf0_bar4_scale {Megabytes} CONFIG.pf0_bar4_size {4} CONFIG.pf0_sriov_bar0_scale {Megabytes} CONFIG.PF0_INTERRUPT_PIN {NONE} CONFIG.pf0_msix_enabled {false}  CONFIG.mode_selection {Advanced} CONFIG.en_msi_per_vec_masking {false} CONFIG.axisten_freq {250} CONFIG.pcie_blk_locn {X0Y1} CONFIG.gen_x0y0 {false} CONFIG.gen_x0y1 {true} CONFIG.axisten_if_width {256_bit} CONFIG.PF0_DEVICE_ID {7038} CONFIG.PF1_DEVICE_ID {7011} CONFIG.pf0_bar2_type {Memory} CONFIG.pf0_bar4_type {Memory} CONFIG.pf0_ari_enabled {true} CONFIG.SRIOV_CAP_ENABLE_EXT {false}] [get_ips pcie3_7x_0]
create_ip_run [get_files -of_objects [get_fileset sources_1] $project_dir/$project_name/$project_name.srcs/sources_1/ip/pcie3_7x_0/pcie3_7x_0.xci]


open_example_project -force -dir /tmp [get_ips  pcie3_7x_0]
close_project
