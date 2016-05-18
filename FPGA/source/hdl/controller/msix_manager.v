// Copyright (c) 2016
// All rights reserved.
//
// as part of the DARPA MRC research programme.
//
// @NETFPGA_LICENSE_HEADER_START@
//
// Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
// license agreements.  See the NOTICE file distributed with this work for
// additional information regarding copyright ownership.  NetFPGA licenses this
// file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
// "License"); you may not use this file except in compliance with the
// License.  You may obtain a copy of the License at:
//
//   http://www.netfpga-cic.org
//
// Unless required by applicable law or agreed to in writing, Work distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations under the License.
//
// @NETFPGA_LICENSE_HEADER_END@


`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company:  HPCN-UAM
// Engineer: Jose Fernando Zazo
//
// Create Date: 06/04/2015 01:04:59 PM
// Module Name: msix_manager
// Description: Implement the MSI-X structure (table and PBA) in a BRAM memory.
//            This module also offers the necessary interconnection for interact with the Xilinx
//            7 Series Integrated block for PCIe.
//            **Signals with higher value have more priority.
//
// Dependencies: bram_tdp, block ram of 36kbits in TDP (true dual port)
//////////////////////////////////////////////////////////////////////////////////



/*


The MSI-X Table Structure contains multiple entries and eachentry represents one interrupt vector. Each entry has 4 QWORDs and consists of a32-bit lower Message Address, 32-bit upper Message Address, 32-bit data, and asingle Mask bit in the Vector Control field as shown in Figure 4 below. When the device wants to transmit a MSI-X interrupt message, it does

Picks up an entry in the Table Structure, sendsout a PCIe memory write with the address and data in the table to the system host.
Sets the associated bit in the PBA structure torepresent which MSI-X interrupt is sent. The host software can read the bit inthe PBA to determine which interrupt is generated and start the correspondinginterrupt service routine.
After the interrupt is serviced, the functionwhich generates the MSI-X interrupt clears the bit.


The following is the flow about how the MSI-X is configured and is used.

The system enumerates the FPGA, the host software does configuration read to the MSI-X Capability register located in the PCIe HIP to determine the table’s size.
The host does memory writes to configure the MSI-X Table.
To issue a MSI-X interrupt, the user logic reads the address and data of an entry in the MSI-X Table structure, packetize a memory write with the address and data and then does an upstream memory write to the system memory in PCIe domain.
The user logic also sets the pending bit in MSI-X PBA structure, which is associated to the entry in the Table structure.
When the system host receives the interrupt, it may read the MSI-X PBA structure through memory read to determine which interrupt is asserted and then calls the appropriate interrupt service routine.
After the interrupt is served, the user logic needs to clear the pending bit in the MSI-X PBA structure.


*/


module msix_manager_br #(
  parameter C_M_AXI_LITE_ADDR_WIDTH = 9      ,
  parameter C_M_AXI_LITE_DATA_WIDTH = 32     ,
  parameter C_M_AXI_LITE_STRB_WIDTH = 32     ,
  parameter C_MSIX_TABLE_OFFSET     = 32'h0  ,
  parameter C_MSIX_PBA_OFFSET       = 32'h100, /* PBA = Pending bit array */
  parameter C_NUM_IRQ_INPUTS        = 1
) (
  input  wire                        clk                         ,
  input  wire                        rst_n                       ,
  /*********************
  * Memory  Interface *
  *********************/
  // Memory Channel
  input  wire                        s_mem_iface_en              ,
  input  wire [                 8:0] s_mem_iface_addr            ,
  output wire [                63:0] s_mem_iface_dout            ,
  input  wire [                63:0] s_mem_iface_din             ,
  input  wire [                 7:0] s_mem_iface_we              ,
  output reg                         s_mem_iface_ack             ,
  // MSI-X interrupts
  input  wire [                 1:0] cfg_interrupt_msix_enable   ,
  input  wire [                 1:0] cfg_interrupt_msix_mask     ,
  input  wire [                 5:0] cfg_interrupt_msix_vf_enable,
  input  wire [                 5:0] cfg_interrupt_msix_vf_mask  ,
  output wire [                31:0] cfg_interrupt_msix_data     ,
  output wire [                63:0] cfg_interrupt_msix_address  ,
  output wire                        cfg_interrupt_msix_int      ,
  input  wire                        cfg_interrupt_msix_sent     ,
  input  wire                        cfg_interrupt_msix_fail     ,
  /********************
  * Interrupt Inputs *
  ********************/
  input  wire [C_NUM_IRQ_INPUTS-1:0] irq
);


  always @(posedge clk) begin
    s_mem_iface_ack  <= s_mem_iface_en;
  end

  // MSI-X IRQ generation logic
  assign cfg_interrupt_msix_address = 64'h0;
  assign cfg_interrupt_msix_data    = 32'h0;
  assign cfg_interrupt_msix_int     = 1'h0;
  assign s_mem_iface_dout           = 0;

endmodule
