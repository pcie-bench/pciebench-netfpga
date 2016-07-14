/**
@class dma_logic

@author      Jose Fernando Zazo Rollon (josefernando.zazo@estudiante.uam.es)
@date        20/04/2015

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

module dma_benchmarking #(
	parameter C_BUS_DATA_WIDTH       = 256 ,
	parameter C_BUS_KEEP_WIDTH = (C_BUS_DATA_WIDTH/32),
	parameter C_ELEMENTS_BEFORE_INIT = 1000, // Elements before any TLP is transferred
	parameter C_NITERATIONS          = 1024, // 8M
	parameter C_MODE                 = 1    // Mode 0 -> Do nothing.
	// Repeat in loop (until reach C_NITERATIONS):
	// · Mode 1 -> Always to the same position
	// · Mode 2 -> Always to successive positions. The user must check that the area is writable!!!
) (
	input  wire                        CLK                        ,
	input  wire                        RST_N                      ,
	input  wire [                 7:0] ORIGINAL_CONTROL_BYTE      ,
	output wire [                 7:0] FAKED_CONTROL_BYTE         ,
	input  wire                        ORIGINAL_ENGINE_VALID      ,
	output wire                        FAKED_ENGINE_VALID         ,
	input  wire [                63:0] ORIGINAL_SIZE_AT_DESCRIPTOR,
	input  wire [                63:0] ORIGINAL_ADDR_AT_DESCRIPTOR,
	output wire [                63:0] FAKED_SIZE_AT_DESCRIPTOR   ,
	output wire [                63:0] FAKED_ADDR_AT_DESCRIPTOR   ,
	input  wire [C_BUS_DATA_WIDTH-1:0] M_AXIS_RQ_TDATA            ,
	input  wire [                59:0] M_AXIS_RQ_TUSER            ,
	input  wire                        M_AXIS_RQ_TLAST            ,
	input  wire [C_BUS_KEEP_WIDTH-1:0] M_AXIS_RQ_TKEEP            ,
	input  wire                        M_AXIS_RQ_TVALID           ,
	output wire [                 3:0] M_AXIS_RQ_TREADY           ,
	output wire [C_BUS_DATA_WIDTH-1:0] FAKED_AXIS_RQ_TDATA        ,
	output wire [                59:0] FAKED_AXIS_RQ_TUSER        ,
	output wire                        FAKED_AXIS_RQ_TLAST        ,
	output wire [C_BUS_KEEP_WIDTH-1:0] FAKED_AXIS_RQ_TKEEP        ,
	output wire                        FAKED_AXIS_RQ_TVALID       ,
	input  wire [                 3:0] FAKED_AXIS_RQ_TREADY       ,
	input  wire                        S_AXIS_RC_TVALID           ,
	input  wire [                21:0] S_AXIS_RC_TREADY           ,
	input  wire                        ORIGINAL_UPDATE_LATENCY    ,
	input  wire [                63:0] ORIGINAL_CURRENT_LATENCY   ,
	input  wire [                63:0] ORIGINAL_TIME_AT_REQ       ,
	input  wire [                63:0] ORIGINAL_TIME_AT_COMP      ,
	input  wire [                63:0] ORIGINAL_BYTES_AT_REQ      ,
	input  wire [                63:0] ORIGINAL_BYTES_AT_COMP     ,
	output wire                        FAKED_UPDATE_LATENCY       ,
	output wire [                63:0] FAKED_CURRENT_LATENCY      ,
	output wire [                63:0] FAKED_TIME_AT_REQ          ,
	output wire [                63:0] FAKED_TIME_AT_COMP         ,
	output wire [                63:0] FAKED_BYTES_AT_REQ         ,
	output wire [                63:0] FAKED_BYTES_AT_COMP
);


	reg [63:0] current_address_r   ;
	reg [63:0] current_size_r      ;
	reg [63:0] current_iteration_r ;
	reg [ 2:0] state               ;
	reg [ 2:0] state_p_r           ;
	reg        faked_engine_valid_r;

	wire [3:0] op_s      ;
	wire       op_valid_s;
	reg  [3:0] op_r      ;
	reg        op_valid_r;
	reg        sop_r     ;
	assign op_s       = M_AXIS_RQ_TDATA[78:75];
	assign op_valid_s = M_AXIS_RQ_TVALID&M_AXIS_RQ_TREADY & sop_r;

	wire is_end_of_operation_s      ;
	wire faked_is_end_of_operation_s;
	reg        faked_update_latency_r ;

	assign is_end_of_operation_s       = ORIGINAL_CONTROL_BYTE[3];
	assign faked_is_end_of_operation_s = FAKED_CONTROL_BYTE[3];
	assign FAKED_CONTROL_BYTE          = C_MODE==0 ?
		ORIGINAL_CONTROL_BYTE :
		{ 4'h0, faked_update_latency_r, 3'h0 };
	assign FAKED_ENGINE_VALID = C_MODE==0 ?
		ORIGINAL_ENGINE_VALID
		: faked_engine_valid_r;
	assign FAKED_SIZE_AT_DESCRIPTOR = C_MODE==0 ?
		ORIGINAL_SIZE_AT_DESCRIPTOR
		: current_size_r;
	assign FAKED_ADDR_AT_DESCRIPTOR = C_MODE==0 ?
		ORIGINAL_ADDR_AT_DESCRIPTOR
		: current_address_r;


	reg  [C_BUS_DATA_WIDTH-1:0] faked_axis_rq_tdata_r ;
	reg  [                59:0] faked_axis_rq_tuser_r ;
	reg                         faked_axis_rq_tlast_r ;
	reg  [C_BUS_KEEP_WIDTH-1:0] faked_axis_rq_tkeep_r ;
	reg                         faked_axis_rq_tvalid_r;
	reg                         faked_axis_rq_tready_r;
	wire [C_BUS_DATA_WIDTH-1:0] faked_axis_rq_tdata_s ;
	wire [                59:0] faked_axis_rq_tuser_s ;
	wire                        faked_axis_rq_tlast_s ;
	wire [                31:0] faked_axis_rq_tkeep_s ;
	wire                        faked_axis_rq_tvalid_s;
	wire                        faked_axis_rq_tready_s;
	wire                        m_axis_rq_tready_s    ;

	assign faked_axis_rq_tready_s = FAKED_AXIS_RQ_TREADY[0];


// Create a fifo:
// create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.0 -module_name fifo_benchmark
// set_property -dict [list CONFIG.INTERFACE_TYPE {AXI_STREAM} CONFIG.TDATA_NUM_BYTES {32} CONFIG.Enable_TLAST {true}  CONFIG.TUSER_WIDTH {60} CONFIG.HAS_TSTRB {false} CONFIG.HAS_TKEEP {true} CONFIG.Input_Depth_axis {4096} CONFIG.Programmable_Empty_Type_axis {Single_Programmable_Empty_Threshold_Input_Port} CONFIG.Reset_Type {Asynchronous_Reset} CONFIG.Full_Flags_Reset_Value {1} CONFIG.TSTRB_WIDTH {32} CONFIG.TKEEP_WIDTH {32} CONFIG.FIFO_Implementation_wach {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_wach {15} CONFIG.Empty_Threshold_Assert_Value_wach {14} CONFIG.FIFO_Implementation_wrch {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_wrch {15} CONFIG.Empty_Threshold_Assert_Value_wrch {14} CONFIG.FIFO_Implementation_rach {Common_Clock_Distributed_RAM} CONFIG.Full_Threshold_Assert_Value_rach {15} CONFIG.Empty_Threshold_Assert_Value_rach {14} CONFIG.Full_Threshold_Assert_Value_axis {4095} CONFIG.Empty_Threshold_Assert_Value_axis {4095}] [get_ips fifo_benchmark]// set_property -dict [list CONFIG.Input_Depth_axis {1024} CONFIG.Full_Threshold_Assert_Value_axis {1023} CONFIG.Programmable_Empty_Type_axis {No_Programmable_Empty_Threshold} CONFIG.Empty_Threshold_Assert_Value_axis {1022}] [get_ips fifo_benchmark]
	wire          fifo_empty_s          ;
	wire [12 : 0] axis_prog_empty_thresh;
	assign axis_prog_empty_thresh = C_ELEMENTS_BEFORE_INIT;
	generate if(C_MODE !=0) begin
			fifo_benchmark fifo_benchmark_i (
				.s_aclk                (CLK                                            ), // input wire s_aclk
				.s_aresetn             (RST_N                                          ), // input wire s_aresetn
				.s_axis_tvalid         (M_AXIS_RQ_TVALID                               ), // input wire s_axis_tvalid
				.s_axis_tready         (m_axis_rq_tready_s                             ), // output wire s_axis_tready
				.s_axis_tdata          (M_AXIS_RQ_TDATA                                ), // input wire [255 : 0] s_axis_tdata
				.s_axis_tkeep          ({{(32-C_BUS_KEEP_WIDTH){1'h0}},M_AXIS_RQ_TKEEP}), // input wire [31 : 0] s_axis_tkeep
				.s_axis_tuser          (M_AXIS_RQ_TUSER                                ), // input wire [59 : 0] s_axis_tuser
				.s_axis_tlast          (M_AXIS_RQ_TLAST                                ), // input wire s_axis_tlast
				
				.m_axis_tvalid         (faked_axis_rq_tvalid_s                         ), // output wire m_axis_tvalid
				.m_axis_tready         (faked_axis_rq_tready_s & faked_axis_rq_tready_r), // input wire m_axis_tready
				.m_axis_tdata          (faked_axis_rq_tdata_s                          ), // output wire [255 : 0] m_axis_tdata
				.m_axis_tkeep          (faked_axis_rq_tkeep_s                          ), // output wire [31 : 0] m_axis_tkeep
				.m_axis_tuser          (faked_axis_rq_tuser_s                          ), // output wire [59 : 0] m_axis_tuser
				.m_axis_tlast          (faked_axis_rq_tlast_s                          ), // output wire m_axis_tlast
				
				.axis_prog_empty_thresh(axis_prog_empty_thresh                         ), // input wire [11 : 0] axis_prog_empty_thresh
				.axis_prog_empty       (fifo_empty_s                                   )  // output wire axis_prog_empty
			);
		end
	endgenerate

	assign FAKED_AXIS_RQ_TDATA  = C_MODE==0 ? M_AXIS_RQ_TDATA : faked_axis_rq_tdata_r;
	assign FAKED_AXIS_RQ_TUSER  = C_MODE==0 ? M_AXIS_RQ_TUSER : faked_axis_rq_tuser_r;
	assign FAKED_AXIS_RQ_TLAST  = C_MODE==0 ? M_AXIS_RQ_TLAST : faked_axis_rq_tlast_r;
	assign FAKED_AXIS_RQ_TKEEP  = C_MODE==0 ? M_AXIS_RQ_TKEEP : faked_axis_rq_tkeep_r;
	assign FAKED_AXIS_RQ_TVALID = C_MODE==0 ? M_AXIS_RQ_TVALID :faked_axis_rq_tvalid_r;
	assign M_AXIS_RQ_TREADY     = C_MODE==0 ? FAKED_AXIS_RQ_TREADY : {4{m_axis_rq_tready_s}};

	reg force_send_r;
	reg stop_r      ;
	reg stop_p_r    ;
	reg stop_p2_r   ;
	always @(negedge RST_N or posedge CLK) begin
		if (!RST_N) begin
			faked_axis_rq_tdata_r  <= 'h0;
			faked_axis_rq_tuser_r  <= 'h0;
			faked_axis_rq_tlast_r  <= 'h0;
			faked_axis_rq_tkeep_r  <= 'h0;
			faked_axis_rq_tvalid_r <= 'h0;
			faked_axis_rq_tready_r <= 'h0;
			force_send_r <= 'h0;
			stop_r <= 'h0;
			stop_p_r <= 'h0;
			stop_p2_r <= 'h0;
		end else begin
			if(faked_axis_rq_tready_s) begin
				faked_axis_rq_tdata_r  <= faked_axis_rq_tdata_s;
				faked_axis_rq_tuser_r  <= faked_axis_rq_tuser_s;
				faked_axis_rq_tlast_r  <= faked_axis_rq_tlast_s;
				faked_axis_rq_tkeep_r  <= faked_axis_rq_tkeep_s[C_BUS_KEEP_WIDTH-1:0];
				faked_axis_rq_tvalid_r <= faked_axis_rq_tvalid_s & faked_axis_rq_tready_r & (!fifo_empty_s | force_send_r);
			end

			faked_axis_rq_tready_r <= faked_axis_rq_tready_s & (!fifo_empty_s | force_send_r);
			stop_p_r <= stop_r;
			stop_p2_r <= stop_p_r;

			if(stop_r) begin
				stop_r <= faked_axis_rq_tvalid_s || !stop_p2_r;
			end else begin
				stop_r <= faked_is_end_of_operation_s;  // Send
			end

			if(force_send_r) begin
				force_send_r  <= faked_axis_rq_tvalid_s || (!faked_axis_rq_tvalid_s && current_iteration_r<C_NITERATIONS);
			end else begin
				force_send_r  <= stop_r ? faked_axis_rq_tvalid_s : !fifo_empty_s;
			end
		end
	end
	always @(negedge RST_N or posedge CLK) begin
		if (!RST_N) begin
			sop_r <= 'h1;
		end else begin
			if(M_AXIS_RQ_TVALID&M_AXIS_RQ_TREADY&M_AXIS_RQ_TLAST) begin
				sop_r <= 1'b1;
			end else if(M_AXIS_RQ_TVALID&M_AXIS_RQ_TREADY) begin
				sop_r <= 1'b0;
			end
		end
	end
	always @(negedge RST_N or posedge CLK) begin
		if (!RST_N) begin
			op_r <= 'h0;
			op_valid_r <= 'h0;
		end else begin
			if(is_end_of_operation_s) begin
				op_valid_r <= 1'b0;
			end else if(M_AXIS_RQ_TVALID&M_AXIS_RQ_TREADY&sop_r) begin
				op_valid_r <= op_valid_s;
				op_r <= op_valid_s ? op_s : op_r;
			end
		end
	end

	reg [5:0] bubble_r;
	always @(negedge RST_N or posedge CLK) begin
		if (!RST_N) begin
			current_size_r       <= 64'b0;
			current_address_r    <= 64'b0;
			faked_engine_valid_r <= 1'b0;
			state                <= 3'b000;
			state_p_r                <= 3'b000;
			current_iteration_r  <= 64'b1;
		end else begin
			state_p_r <= state;
			case(state)
				3'b000 : begin // Waiting for the user
					current_size_r       <= ORIGINAL_SIZE_AT_DESCRIPTOR;
					current_address_r    <= ORIGINAL_ADDR_AT_DESCRIPTOR;
					faked_engine_valid_r <= 1'b0;
					current_iteration_r  <= 64'h1;

					if(ORIGINAL_ENGINE_VALID) begin
						state                <= 3'b001;
						faked_engine_valid_r <= 1'b1;
					end
				end
				3'b001 : begin
					if(is_end_of_operation_s) begin
						if (C_MODE==1) begin
							current_address_r <= ORIGINAL_ADDR_AT_DESCRIPTOR;
						end else if(C_MODE==2) begin
							current_address_r <= current_address_r+current_size_r;
						end

						current_size_r      <= ORIGINAL_SIZE_AT_DESCRIPTOR;
						current_iteration_r <= current_iteration_r + 1;

						if(current_iteration_r==C_NITERATIONS) begin
							state                <= 3'b010;
							faked_engine_valid_r <= 1'b0;
						end
						bubble_r <= 'd3;
					end
				end
				3'b010 : begin // The last writes to the fifo present a latency. Wait 3 pulses
					bubble_r <= bubble_r - 1;
					if(bubble_r==0) begin //Have we extracted all the values from the fifo?
						state  <= (faked_axis_rq_tvalid_r || (!fifo_empty_s || force_send_r)) ? 3'b011 : 3'b100;
					end
				end
				3'b011 : begin
					state  <= (faked_axis_rq_tvalid_r || (!fifo_empty_s || force_send_r))  ? 3'b011 : 3'b100;
				end
				3'b100: begin
					state <= faked_update_latency_r ? 3'b000: 3'b100;
				end
				default : begin
					current_size_r       <= 64'b0;
					current_address_r    <= 64'b0;
					faked_engine_valid_r <= 1'b0;
					state                <= 3'b000;
					current_iteration_r  <= 64'b1;
				end
			endcase
		end
	end


	reg [63:0] faked_current_latency_r;
	reg [63:0] candidate4current_latency_r;
	reg [63:0] faked_time_at_req_r    ;
	reg [63:0] faked_time_at_comp_r   ;
	reg [63:0] faked_bytes_at_req_r   ;
	reg [63:0] faked_bytes_at_comp_r  ;


	reg updating_latency_r;
	always @(negedge RST_N or posedge CLK) begin
		if(!RST_N) begin
			candidate4current_latency_r <= 64'b0;
			updating_latency_r <= 1'b0;
		end else begin
			if(   updating_latency_r // We are updating or this is the first pulse where tvalid is 1.
				|| (faked_axis_rq_tvalid_s & faked_axis_rq_tready_r & (!fifo_empty_s | force_send_r))) begin
				candidate4current_latency_r <= candidate4current_latency_r + 1;
				updating_latency_r <= (state!=3'b00);
			end else if(state==3'b00) begin
				candidate4current_latency_r <= 64'b0;
				updating_latency_r <= 1'b0;
			end
		end
	end
	always @(negedge RST_N or posedge CLK) begin
		if(!RST_N) begin
			faked_current_latency_r <= 64'b0;
		end else begin
			if( (faked_axis_rq_tvalid_s & faked_axis_rq_tready_r ) || (S_AXIS_RC_TVALID && S_AXIS_RC_TREADY)) begin
				faked_current_latency_r <= candidate4current_latency_r + 1;
			end
		end
	end

	always @(negedge RST_N or posedge CLK) begin
		if(!RST_N) begin
			faked_time_at_req_r <= 64'b0;
			faked_time_at_comp_r <= 64'b0;
		end else begin
			if(ORIGINAL_UPDATE_LATENCY) begin
				faked_time_at_req_r <= faked_time_at_req_r + FAKED_TIME_AT_REQ;
				faked_time_at_comp_r <= faked_time_at_comp_r + FAKED_TIME_AT_COMP;
			end else if(state==3'b000) begin
				faked_time_at_req_r <= 64'b0;
				faked_time_at_comp_r <= 64'b0;
			end
		end
	end


	always @(negedge RST_N or posedge CLK) begin
		if(!RST_N) begin
			faked_update_latency_r <= 1'b0;
		end else begin
			if(state_p_r != state && state == 3'b100) begin
				faked_update_latency_r <= 1'b1;
			end else begin
				faked_update_latency_r <= 1'b0;
			end
		end
	end

	always @(negedge RST_N or posedge CLK) begin
		if(!RST_N) begin
			faked_bytes_at_req_r   <= 64'b0;
			faked_bytes_at_comp_r  <= 64'b0;
		end else begin
			if(ORIGINAL_UPDATE_LATENCY) begin
				faked_bytes_at_req_r  <= ORIGINAL_BYTES_AT_REQ*C_NITERATIONS;
				faked_bytes_at_comp_r <= ORIGINAL_BYTES_AT_COMP*C_NITERATIONS;
			end
		end
	end

	assign FAKED_UPDATE_LATENCY  = faked_update_latency_r;
	assign FAKED_CURRENT_LATENCY = faked_current_latency_r;
	assign FAKED_TIME_AT_REQ     = faked_time_at_req_r;
	assign FAKED_TIME_AT_COMP    = faked_time_at_comp_r;
	assign FAKED_BYTES_AT_REQ    = faked_bytes_at_req_r;
	assign FAKED_BYTES_AT_COMP   = faked_bytes_at_comp_r;

endmodule

