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

module dma_benchmarking #(
	parameter C_NITERATIONS = 8, //8388608, // 8M
	parameter C_MODE        = 1 // Mode 0 -> Do nothing.
	// Repeat in loop (until reach C_NITERATIONS):
	// · Mode 1 -> Always to the same position
	// · Mode 2 -> Always to successive positions. The user must check that the area is writable!!!
) (
	input  wire        CLK                        ,
	input  wire        RST_N                      ,
	input  wire [ 7:0] ORIGINAL_CONTROL_BYTE      ,
	output wire [ 7:0] FAKED_CONTROL_BYTE         ,
	input  wire        ORIGINAL_ENGINE_VALID      ,
	output wire        FAKED_ENGINE_VALID         ,
	input  wire [63:0] ORIGINAL_SIZE_AT_DESCRIPTOR,
	input  wire [63:0] ORIGINAL_ADDR_AT_DESCRIPTOR,
	output wire [63:0] FAKED_SIZE_AT_DESCRIPTOR   ,
	output wire [63:0] FAKED_ADDR_AT_DESCRIPTOR
);

	reg [63:0] current_address_r   ;
	reg [63:0] current_size_r      ;
	reg [63:0] current_iteration_r ;
	reg        state               ;
	reg        faked_engine_valid_r;

	wire is_end_of_operation_s;
	assign is_end_of_operation_s    = ORIGINAL_CONTROL_BYTE[3];
	assign FAKED_CONTROL_BYTE       = C_MODE==0 ? 
					ORIGINAL_CONTROL_BYTE :
					{ 4'h0, is_end_of_operation_s && current_iteration_r==C_NITERATIONS, 3'h0 };
	assign FAKED_ENGINE_VALID       = C_MODE==0 ? 
					ORIGINAL_ENGINE_VALID 
					: faked_engine_valid_r;
	assign FAKED_SIZE_AT_DESCRIPTOR = C_MODE==0 ? 
					ORIGINAL_SIZE_AT_DESCRIPTOR 
					: current_size_r;
	assign FAKED_ADDR_AT_DESCRIPTOR = C_MODE==0 ? 
					ORIGINAL_ADDR_AT_DESCRIPTOR 
					: current_address_r;

	always @(negedge RST_N or posedge CLK) begin
		if (!RST_N) begin
			current_size_r       <= 64'b0;
			current_address_r    <= 64'b0;
			faked_engine_valid_r <= 1'b0;
			state                <= 1'b0;
			current_iteration_r  <= 64'b1;
		end else begin
			case(state)
				1'b0 : begin // Waiting for the user
					current_size_r       <= ORIGINAL_SIZE_AT_DESCRIPTOR;
					current_address_r    <= ORIGINAL_ADDR_AT_DESCRIPTOR;
					faked_engine_valid_r <= 1'b0;
					current_iteration_r  <= 64'h1;

					if(ORIGINAL_ENGINE_VALID) begin
						state                <= 1'b1;
						faked_engine_valid_r <= 1'b1;
					end
				end
				1'b1 : begin
					if(is_end_of_operation_s) begin
						if (C_MODE==1) begin
							current_address_r <= ORIGINAL_ADDR_AT_DESCRIPTOR;
						end else if(C_MODE==2) begin
							current_address_r <= current_address_r+current_size_r;
						end

						current_size_r      <= ORIGINAL_SIZE_AT_DESCRIPTOR;
						current_iteration_r <= current_iteration_r + 1;

						if(current_iteration_r==C_NITERATIONS) begin
							state                <= 1'b0;
							faked_engine_valid_r <= 1'b0;
						end
					end
				end
				default : begin
					current_size_r       <= 64'b0;
					current_address_r    <= 64'b0;
					faked_engine_valid_r <= 1'b0;
					state                <= 1'b0;
					current_iteration_r  <= 64'b1;
				end
			endcase
		end
	end

endmodule

