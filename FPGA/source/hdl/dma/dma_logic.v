/**
@class dma_logic

@author      Jose Fernando Zazo Rollon (josefernando.zazo@estudiante.uam.es)
@date        20/04/2015

@brief Top level design containing  the PCIe DMA core

Copyright (c) 2016
All rights reserved.


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

module dma_logic #(
	parameter C_BUS_DATA_WIDTH         = 256     ,
	parameter                                           C_BUS_KEEP_WIDTH = (C_BUS_DATA_WIDTH/32),
	parameter                                           C_AXI_KEEP_WIDTH = (C_BUS_DATA_WIDTH/8),
	parameter C_ADDR_WIDTH             = 16      , //At least 10 (Offset 200)
	parameter C_DATA_WIDTH             = 64      ,
	parameter C_ENGINE_TABLE_OFFSET    = 32'h200 ,
	parameter C_OFFSET_BETWEEN_ENGINES = 16'h2000,
	parameter C_NUM_ENGINES            = 2       ,
	parameter C_WINDOW_SIZE            = 4       , // Number of parallel memory read requests. Must be a value between 1 and 2**9-1
	parameter C_LOG2_MAX_PAYLOAD       = 8       , // 2**C_LOG2_MAX_PAYLOAD in bytes
	parameter C_LOG2_MAX_READ_REQUEST  = 12        // 2**C_LOG2_MAX_READ_REQUEST in bytes
) (
	input  wire                        CLK                ,
	input  wire                        RST_N              ,
	////////////
	//  PCIe Interface: 2 AXI-Stream (requester side)
	////////////
	output wire [C_BUS_DATA_WIDTH-1:0] M_AXIS_RQ_TDATA    ,
	output wire [                59:0] M_AXIS_RQ_TUSER    ,
	output wire                        M_AXIS_RQ_TLAST    ,
	output wire [C_BUS_KEEP_WIDTH-1:0] M_AXIS_RQ_TKEEP    ,
	output wire                        M_AXIS_RQ_TVALID   ,
	input  wire [                 3:0] M_AXIS_RQ_TREADY   ,
	input  wire [C_BUS_DATA_WIDTH-1:0] S_AXIS_RC_TDATA    ,
	input  wire [                74:0] S_AXIS_RC_TUSER    ,
	input  wire                        S_AXIS_RC_TLAST    ,
	input  wire [C_BUS_KEEP_WIDTH-1:0] S_AXIS_RC_TKEEP    ,
	input  wire                        S_AXIS_RC_TVALID   ,
	output wire [                21:0] S_AXIS_RC_TREADY   ,
	////////////
	//  User Interface: 2 AXI-Stream. Every engine will have associate a  C_BUS_DATA_WIDTH
	//  AXI-Stream in each direction.
	////////////
	output wire                        S2C_TVALID         ,
	input  wire                        S2C_TREADY         ,
	output wire [C_BUS_DATA_WIDTH-1:0] S2C_TDATA          ,
	output wire                        S2C_TLAST          ,
	output wire [C_AXI_KEEP_WIDTH-1:0] S2C_TKEEP          ,
	output wire                        C2S_TREADY         ,
	input  wire [C_BUS_DATA_WIDTH-1:0] C2S_TDATA          ,
	input  wire                        C2S_TLAST          ,
	input  wire                        C2S_TVALID         ,
	input  wire [C_AXI_KEEP_WIDTH-1:0] C2S_TKEEP          ,
	////////////
	//  Memory Interface: Master interface, transferences from the CPU.
	////////////
	input  wire                        S_MEM_IFACE_EN     ,
	input  wire [    C_ADDR_WIDTH-1:0] S_MEM_IFACE_ADDR   ,
	output wire [    C_DATA_WIDTH-1:0] S_MEM_IFACE_DOUT   ,
	input  wire [    C_DATA_WIDTH-1:0] S_MEM_IFACE_DIN    ,
	input  wire [  C_DATA_WIDTH/8-1:0] S_MEM_IFACE_WE     ,
	output wire                        S_MEM_IFACE_ACK    ,
	//
	output wire                        OPERATION_IN_COURSE
);


	wire [ 8:0] status_byte_s       ;
	wire [ 7:0] control_byte_s      ;
	wire [63:0] addr_at_descriptor_s;
	wire [63:0] size_at_descriptor_s;
	wire [63:0] window_size_s       ;

	reg  [63:0] byte_count_r   ;
	wire [63:0] byte_count_rc_s;
	wire [63:0] byte_count_rq_s;

	wire        original_update_latency_s ;
	wire [63:0] original_current_latency_s;
	wire [63:0] original_time_req_s       ;
	wire [63:0] original_time_comp_s      ;
	wire [63:0] original_bytes_req_s      ;
	wire [63:0] original_bytes_comp_s     ;

	wire        update_latency_s    ;
	wire [63:0] current_latency_s   ;
	wire [63:0] time_req_s          ;
	wire [63:0] time_comp_s         ;
	wire [63:0] bytes_req_s         ;
	wire [63:0] bytes_comp_s        ;
	wire [63:0] size_at_host_s      ;
	wire [63:0] number_tlps_s       ;
	wire [63:0] address_gen_offset_s;
	wire [63:0] address_gen_incr_s  ;

	wire [C_DATA_WIDTH-1:0] s_mem_iface_dout_dma_reg_s;
	wire                    s_mem_iface_ack_dma_reg_s ;

	reg  user_reset_r  ;
	wire dma_reset_n   ;
	wire valid_engine_s;

	assign dma_reset_n = RST_N & (!user_reset_r);

	dma_engine_manager #(
		.C_ADDR_WIDTH         (C_ADDR_WIDTH         ),
		.C_DATA_WIDTH         (C_DATA_WIDTH         ),
		.C_ENGINE_TABLE_OFFSET(C_ENGINE_TABLE_OFFSET),
		.C_DEFAULT_WINDOW_SIZE(C_WINDOW_SIZE        )
	) dma_engine_manager_i (
		.CLK               (CLK                       ),
		.RST_N             (dma_reset_n               ),
		
		.S_MEM_IFACE_EN    (S_MEM_IFACE_EN            ),
		.S_MEM_IFACE_ADDR  (S_MEM_IFACE_ADDR          ),
		.S_MEM_IFACE_DOUT  (s_mem_iface_dout_dma_reg_s),
		.S_MEM_IFACE_DIN   (S_MEM_IFACE_DIN           ),
		.S_MEM_IFACE_WE    (S_MEM_IFACE_WE            ),
		.S_MEM_IFACE_ACK   (s_mem_iface_ack_dma_reg_s ),
		
		.ACTIVE_ENGINE     (0                         ),
		.VALID_ENGINE      (valid_engine_s            ),
		.STATUS_BYTE       (status_byte_s             ),
		.CONTROL_BYTE      (control_byte_s            ),
		.BYTE_COUNT        (byte_count_r              ),
		.DESCRIPTOR_ADDR   (addr_at_descriptor_s      ),
		.DESCRIPTOR_SIZE   (size_at_descriptor_s      ),
		.SIZE_AT_HOST      (size_at_host_s            ),
		.NUMBER_TLPS       (number_tlps_s             ),
		.ADDRESS_GEN_OFFSET(address_gen_offset_s      ),
		.ADDRESS_GEN_INCR  (address_gen_incr_s        ),
		.WINDOW_SIZE       (window_size_s             ),
		.UPDATE_LATENCY    (update_latency_s          ),
		.CURRENT_LATENCY   (current_latency_s         ),
		.TIME_AT_REQ       (time_req_s                ),
		.TIME_AT_COMP      (time_comp_s               ),
		.BYTES_AT_REQ      (bytes_req_s               ),
		.BYTES_AT_COMP     (bytes_comp_s              ),
		.IRQ               (                          )
	);



	/*
	This process will check for the next engine. It is a balanced implementation
	where every engine has the same priority. A selected engine can operate with
	memory write requests or memory read requests. Multiple directions are not
	supported by this implementation
	*/
	wire [1:0] capabilities         ;
	wire       is_end_of_operation_s;
	wire       is_engine_enable_s   ;
	wire       is_engine_stopped_s  ;

	wire [   C_WINDOW_SIZE-1:0] completed_tags_s;
	wire [   C_WINDOW_SIZE-1:0] busy_tags_s     ;
	wire                        end_of_tag_s    ;
	wire [                 7:0] last_tag_s      ;
	wire [C_WINDOW_SIZE*11-1:0] size_tags_s     ;

	assign capabilities          = status_byte_s[6:5];
	assign is_end_of_operation_s = control_byte_s[3];
	assign is_engine_enable_s    = status_byte_s[0];
	assign is_engine_stopped_s   = status_byte_s[3];

	reg engine_finished_r;

	reg detected_end_r;
	always @(negedge dma_reset_n or posedge CLK) begin
		if(!dma_reset_n) begin
			engine_finished_r <= 1'b1;  // A new engine has to be selected
			detected_end_r    <= 1'b0;
		end else begin
			if(valid_engine_s & engine_finished_r) begin      // Check if the previous engine operation has finished.
				if( is_engine_enable_s & !is_engine_stopped_s) begin   // if the engine is enable and it has not finished
					engine_finished_r <= 1'b0;
				end else begin
					engine_finished_r <= 1'b1;
				end
			end else begin
				if((is_end_of_operation_s || detected_end_r) && M_AXIS_RQ_TREADY) begin   // The rq_logic indicates the stop of a descriptor. Wait until the  RQ_READY so we are sure that the operation has finished.
					engine_finished_r <= 1'b1;
					detected_end_r    <= 1'b0;
				end else if(is_end_of_operation_s) begin   // The rq_logic indicates the stop of a descriptor. Wait until the  RQ_READY so we are sure that the operation has finished.
					engine_finished_r <= 1'b0;
					detected_end_r    <= 1'b1;
				end else begin
					engine_finished_r <= engine_finished_r;
				end
			end
		end
	end
	assign OPERATION_IN_COURSE = !engine_finished_r;


	always @(posedge CLK) begin
		byte_count_r <= 64'b0;
	end


	wire [255:0] c2s_fifo_tdata_s ;
	wire [ 31:0] c2s_fifo_tkeep_s ;
	wire         c2s_fifo_tready_s;
	wire         c2s_fifo_tlast_s ;
	wire         c2s_fifo_tvalid_s;


	user_fifo c2s_fifo_i (
		.s_aclk       (CLK              ),
		.s_aresetn    (dma_reset_n      ),
		.s_axis_tvalid(C2S_TVALID       ),
		.s_axis_tready(C2S_TREADY       ),
		.s_axis_tdata (C2S_TDATA        ),
		.s_axis_tkeep (C2S_TKEEP        ),
		.s_axis_tlast (C2S_TLAST        ),
		.m_axis_tvalid(c2s_fifo_tvalid_s),
		.m_axis_tready(c2s_fifo_tready_s),
		.m_axis_tdata (c2s_fifo_tdata_s ),
		.m_axis_tkeep (c2s_fifo_tkeep_s ),
		.m_axis_tlast (c2s_fifo_tlast_s )
	);

	wire [63:0] word_count_r;

	// Manage the RQ interface
	dma_rq_logic #(
		.C_BUS_DATA_WIDTH       (C_BUS_DATA_WIDTH       ),
		.C_BUS_KEEP_WIDTH       (C_BUS_KEEP_WIDTH       ),
		.C_AXI_KEEP_WIDTH       (C_AXI_KEEP_WIDTH       ),
		.C_WINDOW_SIZE          (C_WINDOW_SIZE          ),
		.C_LOG2_MAX_PAYLOAD     (C_LOG2_MAX_PAYLOAD     ),
		.C_LOG2_MAX_READ_REQUEST(C_LOG2_MAX_READ_REQUEST)
	) dma_rq_logic_i (
		.CLK                (CLK                 ),
		.RST_N              (dma_reset_n         ),
		
		////////////
		//  PCIe Interface: 1 AXI-Stream (requester side)
		////////////
		.M_AXIS_RQ_TDATA    (M_AXIS_RQ_TDATA     ),
		.M_AXIS_RQ_TUSER    (M_AXIS_RQ_TUSER     ),
		.M_AXIS_RQ_TLAST    (M_AXIS_RQ_TLAST     ),
		.M_AXIS_RQ_TKEEP    (M_AXIS_RQ_TKEEP     ),
		.M_AXIS_RQ_TVALID   (M_AXIS_RQ_TVALID    ),
		.M_AXIS_RQ_TREADY   (M_AXIS_RQ_TREADY    ),
		
		
		.S_AXIS_RC_TDATA    (S_AXIS_RC_TDATA     ),
		.S_AXIS_RC_TUSER    (S_AXIS_RC_TUSER     ),
		.S_AXIS_RC_TLAST    (S_AXIS_RC_TLAST     ),
		.S_AXIS_RC_TKEEP    (S_AXIS_RC_TKEEP     ),
		.S_AXIS_RC_TVALID   (S_AXIS_RC_TVALID    ),
		.S_AXIS_RC_TREADY   (S_AXIS_RC_TREADY    ),
		
		////////////
		//  c2s fifo interface: 1 AXI-Stream (data to be transferred in memory write requests)
		////////////
		.C2S_FIFO_TREADY    (c2s_fifo_tready_s   ),
		.C2S_FIFO_TDATA     (c2s_fifo_tdata_s    ),
		.C2S_FIFO_TLAST     (c2s_fifo_tlast_s    ),
		.C2S_FIFO_TVALID    (c2s_fifo_tvalid_s   ),
		.C2S_FIFO_TKEEP     (c2s_fifo_tkeep_s    ),
		////////////
		//  Descriptor interface: Interface with the necessary data to complete a memory read/write request.
		////////////
		.ENGINE_VALID       (valid_engine_s      ),
		.STATUS_BYTE        (status_byte_s       ),
		.CONTROL_BYTE       (control_byte_s      ),
		.BYTE_COUNT         (byte_count_rc_s     ),
		
		
		
		.SIZE_AT_DESCRIPTOR (size_at_descriptor_s),
		.SIZE_AT_HOST       (size_at_host_s      ),
		.NUMBER_TLPS        (number_tlps_s       ),
		.ADDR_AT_DESCRIPTOR (addr_at_descriptor_s),
		.ADDRESS_GEN_OFFSET (address_gen_offset_s),
		.ADDRESS_GEN_INCR   (address_gen_incr_s  ),
		.CURRENT_WINDOW_SIZE(window_size_s       ),
		.UPDATE_LATENCY     (update_latency_s    ),
		
		
		.CURRENT_LATENCY    (current_latency_s   ),
		.TIME_AT_REQ        (time_req_s          ),
		.TIME_AT_COMP       (time_comp_s         ),
		.BYTES_AT_REQ       (bytes_req_s         ),
		.BYTES_AT_COMP      (bytes_comp_s        ),
		.WORD_COUNT         (word_count_r        ),
		.SIZE_TAGS          (size_tags_s         ),
		.COMPLETED_TAGS     (completed_tags_s    ),
		.BUSY_TAGS          (busy_tags_s         ),
		
		.END_OF_TAG         (end_of_tag_s        ),
		.LAST_TAG           (last_tag_s          ),
		.DEBUG              (                    )
	);

	wire [C_BUS_KEEP_WIDTH-1:0] s2c_fifo_tkeep_s         ;
	wire [C_BUS_DATA_WIDTH-1:0] s2c_fifo_tdata_s         ;
	wire                        s2c_fifo_tvalid_s        ;
	wire                        s2c_fifo_tlast_s         ;
	wire [C_AXI_KEEP_WIDTH-1:0] s2c_fifo_tkeep_expanded_s; // s2c_fifo_tkeep_s is expressed in 32 bit words. However, the fifo expect the tkeep signal indicates persistence



	dma_rc_logic #(
		.C_BUS_DATA_WIDTH       (C_BUS_DATA_WIDTH       ),
		.C_BUS_KEEP_WIDTH       (C_BUS_KEEP_WIDTH       ),
		.C_WINDOW_SIZE          (C_WINDOW_SIZE          ),
		.C_LOG2_MAX_PAYLOAD     (C_LOG2_MAX_PAYLOAD     ),
		.C_LOG2_MAX_READ_REQUEST(C_LOG2_MAX_READ_REQUEST)
	) dma_rc_logic_i (
		.CLK                (CLK              ),
		.RST_N              (dma_reset_n      ),
		
		////////////
		//  PCIe Interface: 1 AXI-Stream (requester side)
		////////////
		.S_AXIS_RC_TDATA    (S_AXIS_RC_TDATA  ),
		.S_AXIS_RC_TUSER    (S_AXIS_RC_TUSER  ),
		.S_AXIS_RC_TLAST    (S_AXIS_RC_TLAST  ),
		.S_AXIS_RC_TKEEP    (S_AXIS_RC_TKEEP  ),
		.S_AXIS_RC_TVALID   (S_AXIS_RC_TVALID ),
		.S_AXIS_RC_TREADY   (S_AXIS_RC_TREADY ),
		
		
		////////////
		//  s2c fifo interface: 1 AXI-Stream
		////////////
		.S2C_FIFO_TVALID    (s2c_fifo_tvalid_s),
		.S2C_FIFO_TREADY    (S2C_TREADY       ), // S2C engines are the odd ones.
		.S2C_FIFO_TDATA     (s2c_fifo_tdata_s ),
		.S2C_FIFO_TLAST     (s2c_fifo_tlast_s ),
		.S2C_FIFO_TKEEP     (s2c_fifo_tkeep_s ),
		
		
		
		////////////
		// Descriptor interface: Interface with the necessary data to complete a memory read/write request.
		// Data is generated from dma_c2s_logic
		////////////
		.BYTE_COUNT         (byte_count_rq_s  ),
		.SIZE_TAGS          (size_tags_s      ),
		.COMPLETED_TAGS     (completed_tags_s ),
		
		.END_OF_TAG         (end_of_tag_s     ),
		.LAST_TAG           (last_tag_s       ),
		.WORD_COUNT         (word_count_r     ),
		.BUSY_TAGS          (busy_tags_s      ),
		.CURRENT_WINDOW_SIZE(window_size_s    ),
		.DEBUG              (                 )
	);



	wire [C_AXI_KEEP_WIDTH-1:0] s2c_tkeep_s     ;
	reg  [C_AXI_KEEP_WIDTH-1:0] s2c_tkeep_last_r; // Strobe of the last packet




	assign S2C_TDATA                 = s2c_fifo_tdata_s;
	assign S2C_TVALID                = s2c_fifo_tvalid_s;
	assign S2C_TLAST                 = s2c_fifo_tlast_s;
	assign s2c_fifo_tkeep_expanded_s = { {4{s2c_fifo_tkeep_s[7]}},{4{s2c_fifo_tkeep_s[6]}},{4{s2c_fifo_tkeep_s[5]}},{4{s2c_fifo_tkeep_s[4]}},
		{4{s2c_fifo_tkeep_s[3]}}, {4{s2c_fifo_tkeep_s[2]}},{4{s2c_fifo_tkeep_s[1]}},{4{s2c_fifo_tkeep_s[0]}} };

	assign S2C_TKEEP = S2C_TLAST ? s2c_fifo_tkeep_expanded_s : 32'hffffffff;


////



	reg [C_DATA_WIDTH-1:0] s_mem_iface_dout_ctrl_r;
	reg                    s_mem_iface_ack_ctrl_r ;
	reg                    s_mem_iface_ctrl_r     ;



	wire [2:0] max_payload_common_block_s    ;
	wire [2:0] max_readrequest_common_block_s;

	assign max_payload_common_block_s     = C_LOG2_MAX_PAYLOAD-7;
	assign max_readrequest_common_block_s = C_LOG2_MAX_READ_REQUEST-7;

	always @(negedge dma_reset_n or posedge CLK) begin
		if (!dma_reset_n) begin
			s_mem_iface_ctrl_r      <= 1'b0;
			s_mem_iface_dout_ctrl_r <= 0;
			s_mem_iface_ack_ctrl_r  <= 1'b0;
		end else begin
			s_mem_iface_ack_ctrl_r <= S_MEM_IFACE_EN;
			if(S_MEM_IFACE_EN) begin
				case(S_MEM_IFACE_ADDR)
					C_ENGINE_TABLE_OFFSET + C_NUM_ENGINES*C_OFFSET_BETWEEN_ENGINES: begin
						s_mem_iface_dout_ctrl_r <= { {64-C_NUM_ENGINES-8{1'b0}}, 3'b0,max_readrequest_common_block_s, max_payload_common_block_s};
						s_mem_iface_ack_ctrl_r  <= 1'b1;
					end
					default : begin
						s_mem_iface_ack_ctrl_r <= 1'b0;
					end
				endcase
			end
		end
	end
	always @(negedge dma_reset_n or posedge CLK) begin
		if (!dma_reset_n) begin
			user_reset_r <= 1'b0;
		end else begin
			if(S_MEM_IFACE_EN  && S_MEM_IFACE_WE) begin
				case(S_MEM_IFACE_ADDR)
					C_ENGINE_TABLE_OFFSET + C_NUM_ENGINES*C_OFFSET_BETWEEN_ENGINES : begin
						if(S_MEM_IFACE_WE[0]) begin
							user_reset_r <= S_MEM_IFACE_DIN[7];
						end
					end
					default : begin
						user_reset_r <= 1'b0;
					end
				endcase
			end
		end
	end

	assign S_MEM_IFACE_DOUT = s_mem_iface_ack_ctrl_r ? s_mem_iface_dout_ctrl_r : s_mem_iface_dout_dma_reg_s;
	assign S_MEM_IFACE_ACK  = s_mem_iface_ack_ctrl_r ? s_mem_iface_ack_ctrl_r : s_mem_iface_ack_dma_reg_s;

endmodule

