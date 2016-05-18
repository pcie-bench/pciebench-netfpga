/**
@class dma_sriov_top

@author      Jose Fernando Zazo Rollon (josefernando.zazo@estudiante.uam.es)
@date        20/04/2015

@brief Top level design containing  the PCIe DMA core and SR-IOV level abstractions


 Copyright (c) 2016
 All rights reserved.

 as part of the DARPA MRC research programme.

 @NETFPGA_LICENSE_HEADER_START@

 Licensed to NetFPGA C.I.C. (NetFPGA) under one or more contributor
 license agreements.  See the NOTICE file distributed with this work for
 additional information regarding copyright ownership.  NetFPGA licenses this
 file to you under the NetFPGA Hardware-Software License, Version 1.0 (the
 "License"); you may not use this file except in compliance with the
 License.  You may obtain a copy of the License at:

   http://www.netfpga-cic.org

 Unless required by applicable law or agreed to in writing, Work distributed
 under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 CONDITIONS OF ANY KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations under the License.

 @NETFPGA_LICENSE_HEADER_END@


*/

`timescale  1ns/1ns
/*
NOTATION: some compromises have been adopted.

INPUTS/OUTPUTS   to the module are expressed in capital letters.
INPUTS CONSTANTS to the module are expressed in capital letters.
STATES of a FMS  are expressed in capital letters.

Other values are in lower letters.


A register will be written as name_of_register"_r" (except registers associated to states)
A signal will be written as   name_of_register"_s"

Every constante will be preceded by "c_"name_of_the_constant

*/

// We cant use $clog2 to initialize vectors to 0, so we define the discrete ceil of the log2
`define CLOG2(x) \
(x <= 2) ? 1 : \
(x <= 4) ? 2 : \
(x <= 8) ? 3 : \
(x <= 16) ? 4 : \
(x <= 32) ? 5 : \
(x <= 64) ? 6 : \
(x <= 128) ? 7 : \
(x <= 256) ? 8 : \
(x <= 512) ? 9 : \
(x <= 1024) ? 10 : \
(x <= 2048) ? 11 : 12

module dma_sriov_top #(
	parameter C_BUS_DATA_WIDTH         = 256     ,
	parameter C_BUS_KEEP_WIDTH         = (C_BUS_DATA_WIDTH/32),
	parameter C_AXI_KEEP_WIDTH         = (C_BUS_DATA_WIDTH/8),
	parameter C_ADDR_WIDTH             = 24      , //At least 10 (Offset 200)
	parameter C_DATA_WIDTH             = 64      ,
	parameter C_ENGINE_TABLE_OFFSET    = 32'h200 ,
	parameter C_OFFSET_BETWEEN_ENGINES = 16'h4000,
	parameter C_WINDOW_SIZE            = 32      , // Number of parallel memory read requests. Must be a value between 1 and 2**9-1
	parameter C_LOG2_MAX_PAYLOAD       = 8       , // 2**C_LOG2_MAX_PAYLOAD in bytes
	parameter C_LOG2_MAX_READ_REQUEST  = 12        // 2**C_LOG2_MAX_READ_REQUEST in bytes
) (
	input  wire                        CLK                         ,
	input  wire                        RST_N                       ,
	////////////
	//  PCIe Interface: 2 AXI-Stream (requester side)
	////////////
	output wire [C_BUS_DATA_WIDTH-1:0] M_AXIS_RQ_TDATA             ,
	output wire [                59:0] M_AXIS_RQ_TUSER             ,
	output wire                        M_AXIS_RQ_TLAST             ,
	output wire [C_BUS_KEEP_WIDTH-1:0] M_AXIS_RQ_TKEEP             ,
	output wire                        M_AXIS_RQ_TVALID            ,
	input  wire [                 3:0] M_AXIS_RQ_TREADY            ,
	input  wire [C_BUS_DATA_WIDTH-1:0] S_AXIS_RC_TDATA             ,
	input  wire [                74:0] S_AXIS_RC_TUSER             ,
	input  wire                        S_AXIS_RC_TLAST             ,
	input  wire [C_BUS_KEEP_WIDTH-1:0] S_AXIS_RC_TKEEP             ,
	input  wire                        S_AXIS_RC_TVALID            ,
	output wire [                21:0] S_AXIS_RC_TREADY            ,
	////////////
	//  User Interface: 2 AXI-Stream. Every engine will have associate a  C_BUS_DATA_WIDTH
	//  AXI-Stream in each direction.
	////////////
	output wire                        S2C_TVALID                  ,
	input  wire                        S2C_TREADY                  ,
	output wire [C_BUS_DATA_WIDTH-1:0] S2C_TDATA                   ,
	output wire                        S2C_TLAST                   ,
	output wire [C_AXI_KEEP_WIDTH-1:0] S2C_TKEEP                   ,
	output wire                        C2S_TREADY                  ,
	input  wire [C_BUS_DATA_WIDTH-1:0] C2S_TDATA                   ,
	input  wire                        C2S_TLAST                   ,
	input  wire                        C2S_TVALID                  ,
	input  wire [C_AXI_KEEP_WIDTH-1:0] C2S_TKEEP                   ,
	////////////
	//  Memory Interface: Master interface, transferences from the CPU.
	////////////
	input  wire                        S_MEM_IFACE_EN              ,
	input  wire [    C_ADDR_WIDTH-1:0] S_MEM_IFACE_ADDR            ,
	output wire [    C_DATA_WIDTH-1:0] S_MEM_IFACE_DOUT            ,
	input  wire [    C_DATA_WIDTH-1:0] S_MEM_IFACE_DIN             ,
	input  wire [  C_DATA_WIDTH/8-1:0] S_MEM_IFACE_WE              ,
	output wire                        S_MEM_IFACE_ACK             ,
	// MSI-x Interrupts
	input  wire [                 1:0] cfg_interrupt_msix_enable   ,
	input  wire [                 1:0] cfg_interrupt_msix_mask     ,
	input  wire [                 5:0] cfg_interrupt_msix_vf_enable,
	input  wire [                 5:0] cfg_interrupt_msix_vf_mask  ,
	output wire [                31:0] cfg_interrupt_msix_data     ,
	output wire [                63:0] cfg_interrupt_msix_address  ,
	output wire                        cfg_interrupt_msix_int      ,
	input  wire                        cfg_interrupt_msix_sent     ,
	input  wire                        cfg_interrupt_msix_fail
);


	wire ack_msix_s  ;
	wire ack_dma_s   ;
	reg  valid_dout_r; // 0 msix - 1 dma


	wire [C_BUS_DATA_WIDTH-1:0] m_axis_rq_tdata_dma_s ;
	wire [                59:0] m_axis_rq_tuser_dma_s ;
	wire [C_BUS_KEEP_WIDTH-1:0] m_axis_rq_tkeep_dma_s ;
	wire                        m_axis_rq_tvalid_dma_s;
	wire                        m_axis_rq_tlast_dma_s ;

	wire [C_BUS_DATA_WIDTH-1:0] s_axis_rc_tdata_dma_s ;
	wire                        s_axis_rc_tvalid_dma_s;


	wire en_dma_s                 ;
	wire operation_in_course_dma_s;

	wire [7:0] rc_engine_tag_s;


	wire [63:0] dout_msix_s;
	wire [63:0] dout_dma_s ;


	assign S_MEM_IFACE_DOUT = valid_dout_r == 0 ? dout_msix_s : dout_dma_s;
	assign S_MEM_IFACE_ACK  = valid_dout_r == 0 ?  ack_msix_s : ack_dma_s;


	assign M_AXIS_RQ_TLAST  = m_axis_rq_tlast_dma_s;
	assign M_AXIS_RQ_TDATA  = m_axis_rq_tdata_dma_s;
	assign M_AXIS_RQ_TUSER  = m_axis_rq_tuser_dma_s;
	assign M_AXIS_RQ_TKEEP  = m_axis_rq_tkeep_dma_s;
	assign M_AXIS_RQ_TVALID = m_axis_rq_tvalid_dma_s;

	always @(negedge RST_N or posedge CLK) begin
		if (!RST_N) begin
			valid_dout_r <= 1'b0;
		end else  begin
			if(S_MEM_IFACE_ADDR[15:0] >= C_ENGINE_TABLE_OFFSET) begin
				valid_dout_r <= 1'b1;  // Select the dout from the dma component
			end else begin
				valid_dout_r <= 1'b0;  // Else msix
			end
		end
	end

	wire [31:0] cfg_interrupt_msix_data_dma_s   ;
	wire [63:0] cfg_interrupt_msix_address_dma_s;
	wire        cfg_interrupt_msix_int_dma_s    ;


	assign cfg_interrupt_msix_data    = cfg_interrupt_msix_data_dma_s;
	assign cfg_interrupt_msix_address = cfg_interrupt_msix_address_dma_s;
	assign cfg_interrupt_msix_int     = cfg_interrupt_msix_int_dma_s;



	assign rc_engine_tag_s = S_AXIS_RC_TDATA[71:64];

	assign s_axis_rc_tdata_dma_s[255:72] = S_AXIS_RC_TDATA[255:72];
	assign s_axis_rc_tdata_dma_s[63:0]   = S_AXIS_RC_TDATA[63:0];
	assign s_axis_rc_tdata_dma_s[71:64]  = S_AXIS_RC_TDATA[71:64];
	assign s_axis_rc_tvalid_dma_s        = S_AXIS_RC_TVALID;
	assign en_dma_s                      = S_MEM_IFACE_EN;


	//////
	// Instantiate a dma_logic for every virtual device.
	dma_logic #(
		.C_ENGINE_TABLE_OFFSET   (C_ENGINE_TABLE_OFFSET   ),
		.C_ADDR_WIDTH            (16                      ),
		.C_DATA_WIDTH            (C_DATA_WIDTH            ),
		.C_OFFSET_BETWEEN_ENGINES(C_OFFSET_BETWEEN_ENGINES),
		.C_WINDOW_SIZE           (C_WINDOW_SIZE           ),
		.C_LOG2_MAX_PAYLOAD      (C_LOG2_MAX_PAYLOAD      ),
		.C_LOG2_MAX_READ_REQUEST (C_LOG2_MAX_READ_REQUEST )
	) dma_logic_i (
		.CLK                (CLK                                                        ),
		.RST_N              (RST_N                                                      ),
		
		.M_AXIS_RQ_TDATA    (m_axis_rq_tdata_dma_s                                      ),
		.M_AXIS_RQ_TUSER    (m_axis_rq_tuser_dma_s                                      ),
		.M_AXIS_RQ_TLAST    (m_axis_rq_tlast_dma_s                                      ),
		.M_AXIS_RQ_TKEEP    (m_axis_rq_tkeep_dma_s                                      ),
		.M_AXIS_RQ_TVALID   (m_axis_rq_tvalid_dma_s                                     ),
		.M_AXIS_RQ_TREADY   (M_AXIS_RQ_TREADY                                           ),
		
		.S_AXIS_RC_TDATA    (s_axis_rc_tdata_dma_s                                      ),
		.S_AXIS_RC_TUSER    (S_AXIS_RC_TUSER                                            ),
		.S_AXIS_RC_TLAST    (S_AXIS_RC_TLAST                                            ),
		.S_AXIS_RC_TKEEP    (S_AXIS_RC_TKEEP                                            ),
		.S_AXIS_RC_TVALID   (s_axis_rc_tvalid_dma_s                                     ),
		.S_AXIS_RC_TREADY   (S_AXIS_RC_TREADY                                           ),
		
		
		.C2S_TVALID         (C2S_TVALID                                                 ),
		.C2S_TREADY         (C2S_TREADY                                                 ),
		.C2S_TDATA          (C2S_TDATA[C_BUS_DATA_WIDTH-1:0]                            ),
		.C2S_TLAST          (C2S_TLAST                                                  ),
		.C2S_TKEEP          (C2S_TKEEP[C_AXI_KEEP_WIDTH-1:0]                            ),
		
		.S2C_TVALID         (S2C_TVALID                                                 ),
		.S2C_TREADY         (S2C_TREADY                                                 ),
		.S2C_TDATA          (S2C_TDATA[C_BUS_DATA_WIDTH-1:0]                            ),
		.S2C_TLAST          (S2C_TLAST                                                  ),
		.S2C_TKEEP          (S2C_TKEEP[C_AXI_KEEP_WIDTH-1:0]                            ),
		
		.S_MEM_IFACE_EN     (en_dma_s && (S_MEM_IFACE_ADDR[15:0]>=C_ENGINE_TABLE_OFFSET)),
		.S_MEM_IFACE_ADDR   (S_MEM_IFACE_ADDR[15:0]                                     ),
		.S_MEM_IFACE_DOUT   (dout_dma_s                                                 ),
		.S_MEM_IFACE_DIN    (S_MEM_IFACE_DIN                                            ),
		.S_MEM_IFACE_WE     (S_MEM_IFACE_WE                                             ),
		.S_MEM_IFACE_ACK    (ack_dma_s                                                  ),
		.IRQ                (                                                           ),
		.OPERATION_IN_COURSE(operation_in_course_dma_s                                  )
	);



	msix_manager_br #(
		.C_MSIX_TABLE_OFFSET(32'h0  ),
		.C_MSIX_PBA_OFFSET  (32'h100), /* PBA = Pending bit array */
		.C_NUM_IRQ_INPUTS   (2      )
	) msix_manager_br_i (
		.clk                         (CLK                                                             ), // input   wire
		.rst_n                       (RST_N                                                           ), // input   wire
		
		.s_mem_iface_en              (S_MEM_IFACE_EN && (S_MEM_IFACE_ADDR[15:0]<C_ENGINE_TABLE_OFFSET)), // input  wire
		.s_mem_iface_addr            (S_MEM_IFACE_ADDR[8:0]                                           ), // input  wire   [8:0]
		.s_mem_iface_dout            (dout_msix_s                                                     ), // output  wire   [63:0]
		.s_mem_iface_din             (S_MEM_IFACE_DIN                                                 ), // input wire   [63:0]
		.s_mem_iface_we              (S_MEM_IFACE_WE                                                  ), // input wire   [7:0]
		.s_mem_iface_ack             (ack_msix_s                                                      ), // output  wire
		
		// MSI-X interrupts
		.cfg_interrupt_msix_enable   (cfg_interrupt_msix_enable                                       ), // input  wire [1:0]
		.cfg_interrupt_msix_mask     (cfg_interrupt_msix_mask                                         ), // input  wire [1:0]
		.cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable                                    ), // input  wire [5:0]
		.cfg_interrupt_msix_vf_mask  (cfg_interrupt_msix_vf_mask                                      ), // input  wire [5:0]
		.cfg_interrupt_msix_data     (cfg_interrupt_msix_data_dma_s                                   ), // output reg  [31:0]
		.cfg_interrupt_msix_address  (cfg_interrupt_msix_address_dma_s                                ), // output wire [63:0]
		.cfg_interrupt_msix_int      (cfg_interrupt_msix_int_dma_s                                    ), // output reg
		.cfg_interrupt_msix_sent     (cfg_interrupt_msix_sent                                         ), // input  wire
		.cfg_interrupt_msix_fail     (cfg_interrupt_msix_fail                                         ), // input  wire
		
		.irq                         (0                                                               )  // input  wire [C_NUM_IRQ_INPUTS-1:0]           // TODO implement
	);




endmodule

