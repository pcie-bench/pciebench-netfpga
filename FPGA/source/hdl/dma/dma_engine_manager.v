/**
@class dma_descriptor_reg

@author      Jose Fernando Zazo Rollon (josefernando.zazo@estudiante.uam.es)
@date        20/04/2015

@brief Register the informationa associated with the different descriptors in used by the app.


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

module dma_engine_manager #(
  parameter C_ADDR_WIDTH          = 16           ,
  parameter C_DATA_WIDTH          = 64           ,
  parameter C_ENGINE_TABLE_OFFSET = 32'h200      , // Offset in the bar for every engine:
  // engine i will be at position  C_ENGINE_TABLE_OFFSET
  parameter C_NUM_DESCRIPTORS     = 1024         , // Number of descriptors represented in each engine.
  parameter C_DEFAULT_TIMEOUT     = 64'd100000000, // 100 ms
  parameter C_DEFAULT_WINDOW_SIZE = 64'd4
) (
  input  wire                      CLK                      ,
  input  wire                      RST_N                    ,
  ///////////
  // Connection with the core Completer DMA interface
  ///////////
  input  wire                      S_MEM_IFACE_EN           ,
  input  wire [  C_ADDR_WIDTH-1:0] S_MEM_IFACE_ADDR         ,
  output wire [  C_DATA_WIDTH-1:0] S_MEM_IFACE_DOUT         ,
  input  wire [  C_DATA_WIDTH-1:0] S_MEM_IFACE_DIN          ,
  input  wire [C_DATA_WIDTH/8-1:0] S_MEM_IFACE_WE           ,
  output reg                       S_MEM_IFACE_ACK          ,
  ///////////
  // Connection with the core Requester DMA interface
  ///////////
  input  wire                      ACTIVE_ENGINE            ,
  output wire [               8:0] STATUS_BYTE       ,
  input  wire [               7:0] CONTROL_BYTE             ,
  input  wire [              63:0] BYTE_COUNT               ,
  output reg                       VALID_ENGINE             ,
  output reg  [              63:0] DESCRIPTOR_ADDR          ,
  output reg  [              63:0] DESCRIPTOR_SIZE          ,
  output wire [              63:0] SIZE_AT_HOST      ,
  output wire [              63:0] NUMBER_TLPS       ,
  output wire [              63:0] ADDRESS_GEN_OFFSET,
  output wire [              63:0] ADDRESS_GEN_INCR  ,
  output reg  [              63:0] WINDOW_SIZE              ,
  input  wire                      UPDATE_LATENCY           ,
  input  wire [              63:0] CURRENT_LATENCY          ,
  input  wire [              63:0] TIME_AT_REQ              ,
  input  wire [              63:0] TIME_AT_COMP             ,
  input  wire [              63:0] BYTES_AT_REQ             ,
  input  wire [              63:0] BYTES_AT_COMP            ,
  output wire                      IRQ
);

  assign DWORD_TLP = 0; //express in 32 bits words. Not used



  localparam c_offset_between_descriptors = 10'h8;
  localparam c_offset_engines_config      = 10'h8; // Descriptor j of engine i will be at position  C_ENGINE_TABLE_OFFSET  + j*c_offset_between_descriptors + c_offset_engines_config

  reg mem_ack_pending_pipe_1_r, mem_ack_pending_pipe_2_r, mem_ack_pending_pipe_3_r;

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      S_MEM_IFACE_ACK          <= 1'b0;
      mem_ack_pending_pipe_1_r <= 1'b0;
      mem_ack_pending_pipe_2_r <= 1'b0;
      mem_ack_pending_pipe_3_r <= 1'b0;
    end else begin
      mem_ack_pending_pipe_1_r <= S_MEM_IFACE_EN;
      mem_ack_pending_pipe_2_r <= mem_ack_pending_pipe_1_r;
      mem_ack_pending_pipe_3_r <= mem_ack_pending_pipe_2_r;
      S_MEM_IFACE_ACK          <= mem_ack_pending_pipe_3_r;
    end
  end



  // DMA engine registers implementation
  reg        enable_r      ;
  reg        reset_r       ;
  reg        running_r     ;
  reg        stop_r        ;
  reg        error_r       ;
  reg [ 1:0] capabilities_r;
  reg [ 1:0] address_mode_r;
  reg [63:0] time_r        ;
  reg [63:0] byte_count_r  ;

  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] last_index_descriptor_r;


  reg [             C_DATA_WIDTH-1:0] rdata_engine_r           ;
  reg [             C_DATA_WIDTH-1:0] rdata_descriptor_r       ;
  reg                                 is_engine_read_r         ;
  reg                                 cl_engine_stats_r        ;
  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] active_index_descriptor_r;
  reg [63:0] window_size_r;
  reg [                         63:0] buffer_at_host_r         ;
  reg [                         63:0] number_tlps_r            ;
  reg [                         63:0] address_gen_offset_r     ;
  reg [                         63:0] address_gen_incr_r       ;

  //////////////////////////
  // BRAM Interface
  //////////////////////////

  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] addra_size_r      ;
  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] addra_address_r   ;
  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] addra_control_r   ;
  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] addra_time_r      ;
  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] addra_comp_time_r ;
  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] addra_req_time_r  ;
  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] addra_comp_bytes_r;
  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] addra_req_bytes_r ;

  // Enable and write port
  reg        ena_size_r       ;
  reg        ena_address_r    ;
  reg        ena_control_r    ;
  reg        ena_time_r       ;
  reg [ 7:0] wea_size_r       ;
  reg [ 7:0] wea_address_r    ;
  reg [ 7:0] wea_control_r    ;
  reg [ 7:0] wea_time_r       ;
  reg [63:0] dina_size_r      ;
  reg [63:0] dina_address_r   ;
  reg [63:0] dina_control_r   ;
  reg [63:0] dina_time_r      ;
  reg [63:0] dina_req_time_r  ;
  reg [63:0] dina_comp_time_r ;
  reg [63:0] dina_req_bytes_r ;
  reg [63:0] dina_comp_bytes_r;

  wire [63:0] doutb_size_s   ;
  wire [63:0] douta_size_s   ; // The user has to read the size from the FIFO just in case it has been altered
  wire [63:0] doutb_address_s;
  wire [63:0] douta_address_s;
  wire [63:0] doutb_control_s;
  wire [63:0] douta_control_s;

  wire [63:0] douta_time_s      ;
  wire [63:0] doutb_time_s      ;
  wire [63:0] douta_comp_time_s ;
  wire [63:0] doutb_comp_time_s ;
  wire [63:0] douta_req_time_s  ;
  wire [63:0] doutb_req_time_s  ;
  wire [63:0] douta_comp_bytes_s;
  wire [63:0] doutb_comp_bytes_s;
  wire [63:0] douta_req_bytes_s ;
  wire [63:0] doutb_req_bytes_s ;


  //



  wire is_end_of_operation_s;
  wire operation_error_s    ;

  assign is_end_of_operation_s = CONTROL_BYTE[3];
  assign operation_error_s     = CONTROL_BYTE[4];
  assign STATUS_BYTE           = {address_mode_r[1:0],capabilities_r[1:0],error_r, stop_r,running_r,reset_r,enable_r};
  assign SIZE_AT_HOST          = buffer_at_host_r;
  assign NUMBER_TLPS           = number_tlps_r;

  assign ADDRESS_GEN_OFFSET = address_gen_offset_r;
  assign ADDRESS_GEN_INCR   = address_gen_incr_r;

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      DESCRIPTOR_ADDR        <= 64'h0;
      DESCRIPTOR_SIZE        <= 64'h0;
      WINDOW_SIZE            <= C_DEFAULT_WINDOW_SIZE;
    end else begin
      DESCRIPTOR_ADDR        <= doutb_address_s;
      DESCRIPTOR_SIZE        <= doutb_size_s;
      WINDOW_SIZE            <= window_size_r;
    end
  end

  reg                                 active_engine_pipe_r          ;
  reg [$clog2(C_NUM_DESCRIPTORS)-1:0] active_index_descriptor_pipe_r;

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      active_engine_pipe_r           <= 0;
      active_index_descriptor_pipe_r <= 0;
    end else begin
      active_engine_pipe_r           <= ACTIVE_ENGINE;
      active_index_descriptor_pipe_r <= active_index_descriptor_r;
    end
  end

  // The output have to wait  some cycles until it is available
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      VALID_ENGINE <= 1'h0;
    end else begin
      if(is_end_of_operation_s) begin // If the user chooses another ENGINE or an operation finishes disable the valid signal.
        VALID_ENGINE <= !(active_index_descriptor_r == last_index_descriptor_r);
      end else if(ACTIVE_ENGINE == active_engine_pipe_r && active_index_descriptor_r == active_index_descriptor_pipe_r && enable_r) begin
        VALID_ENGINE <= 1'h1;
      end else begin
        VALID_ENGINE <= 1'h0;
      end
    end
  end

  assign S_MEM_IFACE_DOUT = is_engine_read_r ?  rdata_engine_r : rdata_descriptor_r;


  // Write logic to regs based on the user decission
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      enable_r <= 1'b0;
      reset_r  <= 1'b0;

      cl_engine_stats_r       <= 1'b0;
      last_index_descriptor_r <= 0;
      capabilities_r          <= 2'b10; // S2C by default
      address_mode_r          <= 2'b00; // Fixed by default
      window_size_r           <= C_DEFAULT_WINDOW_SIZE;
      buffer_at_host_r        <= 64'h0;
      address_gen_offset_r    <= 64'h0;
      address_gen_incr_r      <= 64'h0;
      number_tlps_r           <= 64'h0;
    end else begin
      reset_r           <= 1'b0; // Automatically clean the reset_r after one cycle.
      cl_engine_stats_r <= 1'b0;
      enable_r          <= enable_r & (!stop_r);

      if(S_MEM_IFACE_EN && S_MEM_IFACE_WE) begin
        case(S_MEM_IFACE_ADDR)
          C_ENGINE_TABLE_OFFSET : begin  // Control byte of DMA engine
            // Clean values.

            // Update values
            if(S_MEM_IFACE_WE[0]) begin
              address_mode_r    = S_MEM_IFACE_DIN[5:4]; // Odd engines -> C2S. Even engines -> S2C
              capabilities_r = S_MEM_IFACE_DIN[3:2]; // Odd engines -> C2S. Even engines -> S2C
              cl_engine_stats_r <= S_MEM_IFACE_DIN[1] | S_MEM_IFACE_DIN[0];
              reset_r        <= S_MEM_IFACE_DIN[1];
              enable_r       <= S_MEM_IFACE_DIN[0];
            end
          end
          C_ENGINE_TABLE_OFFSET  + 1: begin      // Stop at descriptor ...
            if(`CLOG2(C_NUM_DESCRIPTORS)<=8) begin
              if(S_MEM_IFACE_WE[0]) last_index_descriptor_r   <= S_MEM_IFACE_DIN[`CLOG2(C_NUM_DESCRIPTORS)-1:0];
            end else begin
              if(S_MEM_IFACE_WE[0]) last_index_descriptor_r[7:0]                                <= S_MEM_IFACE_DIN[7:0];
              if(S_MEM_IFACE_WE[1]) last_index_descriptor_r[`CLOG2(C_NUM_DESCRIPTORS)-1:8]      <= S_MEM_IFACE_DIN[`CLOG2(C_NUM_DESCRIPTORS)-1:8];
            end
          end
          C_ENGINE_TABLE_OFFSET  + 3: begin
            if(S_MEM_IFACE_WE[0]) window_size_r[7:0]    <= S_MEM_IFACE_DIN[7:0];
            if(S_MEM_IFACE_WE[1]) window_size_r[15:8]   <= S_MEM_IFACE_DIN[15:8];
            if(S_MEM_IFACE_WE[2]) window_size_r[23:16]  <= S_MEM_IFACE_DIN[23:16];
            if(S_MEM_IFACE_WE[3]) window_size_r[31:24]  <= S_MEM_IFACE_DIN[31:24];
            if(S_MEM_IFACE_WE[4]) window_size_r[39:32]  <= S_MEM_IFACE_DIN[39:32];
            if(S_MEM_IFACE_WE[5]) window_size_r[47:40]  <= S_MEM_IFACE_DIN[47:40];
            if(S_MEM_IFACE_WE[6]) window_size_r[55:48]  <= S_MEM_IFACE_DIN[55:48];
            if(S_MEM_IFACE_WE[7]) window_size_r[63:56]  <= S_MEM_IFACE_DIN[63:56];
          end
          C_ENGINE_TABLE_OFFSET  + 4: begin
            if(S_MEM_IFACE_WE[0]) buffer_at_host_r[7:0]    <= S_MEM_IFACE_DIN[7:0];
            if(S_MEM_IFACE_WE[1]) buffer_at_host_r[15:8]   <= S_MEM_IFACE_DIN[15:8];
            if(S_MEM_IFACE_WE[2]) buffer_at_host_r[23:16]  <= S_MEM_IFACE_DIN[23:16];
            if(S_MEM_IFACE_WE[3]) buffer_at_host_r[31:24]  <= S_MEM_IFACE_DIN[31:24];
            if(S_MEM_IFACE_WE[4]) buffer_at_host_r[39:32]  <= S_MEM_IFACE_DIN[39:32];
            if(S_MEM_IFACE_WE[5]) buffer_at_host_r[47:40]  <= S_MEM_IFACE_DIN[47:40];
            if(S_MEM_IFACE_WE[6]) buffer_at_host_r[55:48]  <= S_MEM_IFACE_DIN[55:48];
            if(S_MEM_IFACE_WE[7]) buffer_at_host_r[63:56]  <= S_MEM_IFACE_DIN[63:56];
          end
          C_ENGINE_TABLE_OFFSET  + 5: begin
            if(S_MEM_IFACE_WE[0]) address_gen_offset_r[7:0]    <= S_MEM_IFACE_DIN[7:0];
            if(S_MEM_IFACE_WE[1]) address_gen_offset_r[15:8]   <= S_MEM_IFACE_DIN[15:8];
            if(S_MEM_IFACE_WE[2]) address_gen_offset_r[23:16]  <= S_MEM_IFACE_DIN[23:16];
            if(S_MEM_IFACE_WE[3]) address_gen_offset_r[31:24]  <= S_MEM_IFACE_DIN[31:24];
            if(S_MEM_IFACE_WE[4]) address_gen_offset_r[39:32]  <= S_MEM_IFACE_DIN[39:32];
            if(S_MEM_IFACE_WE[5]) address_gen_offset_r[47:40]  <= S_MEM_IFACE_DIN[47:40];
            if(S_MEM_IFACE_WE[6]) address_gen_offset_r[55:48]  <= S_MEM_IFACE_DIN[55:48];
            if(S_MEM_IFACE_WE[7]) address_gen_offset_r[63:56]  <= S_MEM_IFACE_DIN[63:56];
          end
          C_ENGINE_TABLE_OFFSET  + 6: begin
            if(S_MEM_IFACE_WE[0]) address_gen_incr_r[7:0]    <= S_MEM_IFACE_DIN[7:0];
            if(S_MEM_IFACE_WE[1]) address_gen_incr_r[15:8]   <= S_MEM_IFACE_DIN[15:8];
            if(S_MEM_IFACE_WE[2]) address_gen_incr_r[23:16]  <= S_MEM_IFACE_DIN[23:16];
            if(S_MEM_IFACE_WE[3]) address_gen_incr_r[31:24]  <= S_MEM_IFACE_DIN[31:24];
            if(S_MEM_IFACE_WE[4]) address_gen_incr_r[39:32]  <= S_MEM_IFACE_DIN[39:32];
            if(S_MEM_IFACE_WE[5]) address_gen_incr_r[47:40]  <= S_MEM_IFACE_DIN[47:40];
            if(S_MEM_IFACE_WE[6]) address_gen_incr_r[55:48]  <= S_MEM_IFACE_DIN[55:48];
            if(S_MEM_IFACE_WE[7]) address_gen_incr_r[63:56]  <= S_MEM_IFACE_DIN[63:56];
          end
          C_ENGINE_TABLE_OFFSET  + 7: begin
            if(S_MEM_IFACE_WE[0]) number_tlps_r[7:0]    <= S_MEM_IFACE_DIN[7:0];
            if(S_MEM_IFACE_WE[1]) number_tlps_r[15:8]   <= S_MEM_IFACE_DIN[15:8];
            if(S_MEM_IFACE_WE[2]) number_tlps_r[23:16]  <= S_MEM_IFACE_DIN[23:16];
            if(S_MEM_IFACE_WE[3]) number_tlps_r[31:24]  <= S_MEM_IFACE_DIN[31:24];
            if(S_MEM_IFACE_WE[4]) number_tlps_r[39:32]  <= S_MEM_IFACE_DIN[39:32];
            if(S_MEM_IFACE_WE[5]) number_tlps_r[47:40]  <= S_MEM_IFACE_DIN[47:40];
            if(S_MEM_IFACE_WE[6]) number_tlps_r[55:48]  <= S_MEM_IFACE_DIN[55:48];
            if(S_MEM_IFACE_WE[7]) number_tlps_r[63:56]  <= S_MEM_IFACE_DIN[63:56];
          end
          default : begin
          end
        endcase
      end
    end
  end


  // BRAM instantation.


  blk_mem_descriptor blk_mem_descriptor_size (
    .clka (CLK                      ), // input wire clka
    .ena  (ena_size_r               ), // input wire ena
    .wea  (wea_size_r               ), // input wire [7 : 0] wea
    .addra(addra_size_r             ), // input wire [9 : 0] addra
    .dina (dina_size_r              ), // input wire [63 : 0] dina
    .douta(douta_size_s             ), // output wire [63 : 0] douta
    .clkb (CLK                      ), // input wire clkb
    .enb  (1'b1                     ), // input wire enb
    .addrb(active_index_descriptor_r), //(S_MEM_IFACE_ADDR-i*C_OFFSET_BETWEEN_ENGINES-c_offset_engines_config-1)/c_offset_between_descriptors),  // input wire [9 : 0] addrb
    .web  (8'b0                     ), // input wire [0 : 0] web
    .dinb (64'b0                    ), // input wire [63 : 0] dinb
    .doutb(doutb_size_s             )  // output wire [63 : 0] doutb
  );
  blk_mem_descriptor blk_mem_descriptor_address (
    .clka (CLK                      ), // input wire clka
    .ena  (ena_address_r            ), // input wire ena
    .wea  (wea_address_r            ), // input wire [7 : 0] wea
    .addra(addra_address_r          ), // input wire [9 : 0] addra
    .dina (dina_address_r           ), // input wire [63 : 0] dina
    .douta(douta_address_s          ), // output wire [63 : 0] douta
    .clkb (CLK                      ), // input wire clkb
    .enb  (1'b1                     ), // input wire enb
    .addrb(active_index_descriptor_r), //(S_MEM_IFACE_ADDR-i*C_OFFSET_BETWEEN_ENGINES-c_offset_engines_config)/c_offset_between_descriptors),  // input wire [9 : 0] addrb
    .web  (8'b0                     ), // input wire [0 : 0] web
    .dinb (64'b0                    ), // input wire [63 : 0] dinb
    .doutb(doutb_address_s          )  // output wire [63 : 0] doutb
  );
  blk_mem_descriptor blk_mem_descriptor_control (
    .clka (CLK                      ), // input wire clka
    .ena  (ena_control_r            ), // input wire ena
    .wea  (wea_control_r            ), // input wire [7 : 0] wea
    .addra(addra_control_r          ), // input wire [9 : 0] addra
    .dina (dina_control_r           ), // input wire [63 : 0] dina
    .douta(douta_control_s          ), // output wire [63 : 0] douta
    .clkb (CLK                      ), // input wire clkb
    .enb  (1'b1                     ), // input wire enb
    .addrb(active_index_descriptor_r), //(S_MEM_IFACE_ADDR-i*C_OFFSET_BETWEEN_ENGINES-c_offset_engines_config-2)/c_offset_between_descriptors),  // input wire [9 : 0] addrb
    .web  (8'b0                     ), // input wire [0 : 0] web
    .dinb (64'b0                    ), // input wire [63 : 0] dinb
    .doutb(doutb_control_s          )  // output wire [63 : 0] doutb
  );


  blk_mem_descriptor blk_mem_descriptor_time (
    .clka (CLK                      ), // input wire clka
    .ena  (ena_time_r               ), // input wire ena
    .wea  (wea_time_r               ), // input wire [7 : 0] wea
    .addra(active_index_descriptor_r), // input wire [9 : 0] addra
    .dina (dina_time_r              ), // input wire [63 : 0] dina
    .douta(douta_time_s             ), // output wire [63 : 0] douta
    .clkb (CLK                      ), // input wire clkb
    .enb  (1'b1                     ), // input wire enb
    .addrb(addra_time_r             ), //(S_MEM_IFACE_ADDR-i*C_OFFSET_BETWEEN_ENGINES-c_offset_engines_config-2)/c_offset_between_descriptors),  // input wire [9 : 0] addrb
    .web  (8'b0                     ), // input wire [0 : 0] web
    .dinb (64'b0                    ), // input wire [63 : 0] dinb
    .doutb(doutb_time_s             )  // output wire [63 : 0] doutb
  );


  blk_mem_descriptor blk_mem_descriptor_req_time (
    .clka (CLK                      ), // input wire clka
    .ena  (ena_time_r               ), // input wire ena
    .wea  (wea_time_r               ), // input wire [7 : 0] wea
    .addra(active_index_descriptor_r), // input wire [9 : 0] addra
    .dina (dina_req_time_r          ), // input wire [63 : 0] dina
    .douta(douta_req_time_s         ), // output wire [63 : 0] douta
    .clkb (CLK                      ), // input wire clkb
    .enb  (1'b1                     ), // input wire enb
    .addrb(addra_req_time_r         ), //(S_MEM_IFACE_ADDR-i*C_OFFSET_BETWEEN_ENGINES-c_offset_engines_config-2)/c_offset_between_descriptors),  // input wire [9 : 0] addrb
    .web  (8'b0                     ), // input wire [0 : 0] web
    .dinb (64'b0                    ), // input wire [63 : 0] dinb
    .doutb(doutb_req_time_s         )  // output wire [63 : 0] doutb
  );
  blk_mem_descriptor blk_mem_descriptor_comp_time (
    .clka (CLK                      ), // input wire clka
    .ena  (ena_time_r               ), // input wire ena
    .wea  (wea_time_r               ), // input wire [7 : 0] wea
    .addra(active_index_descriptor_r), // input wire [9 : 0] addra
    .dina (dina_comp_time_r         ), // input wire [63 : 0] dina
    .douta(douta_comp_time_s        ), // output wire [63 : 0] douta
    .clkb (CLK                      ), // input wire clkb
    .enb  (1'b1                     ), // input wire enb
    .addrb(addra_comp_time_r        ), //(S_MEM_IFACE_ADDR-i*C_OFFSET_BETWEEN_ENGINES-c_offset_engines_config-2)/c_offset_between_descriptors),  // input wire [9 : 0] addrb
    .web  (8'b0                     ), // input wire [0 : 0] web
    .dinb (64'b0                    ), // input wire [63 : 0] dinb
    .doutb(doutb_comp_time_s        )  // output wire [63 : 0] doutb
  );
  blk_mem_descriptor blk_mem_descriptor_req_bytes (
    .clka (CLK                      ), // input wire clka
    .ena  (ena_time_r               ), // input wire ena
    .wea  (wea_time_r               ), // input wire [7 : 0] wea
    .addra(active_index_descriptor_r), // input wire [9 : 0] addra
    .dina (dina_req_bytes_r         ), // input wire [63 : 0] dina
    .douta(douta_req_bytes_s        ), // output wire [63 : 0] douta
    .clkb (CLK                      ), // input wire clkb
    .enb  (1'b1                     ), // input wire enb
    .addrb(addra_req_bytes_r        ), //(S_MEM_IFACE_ADDR-i*C_OFFSET_BETWEEN_ENGINES-c_offset_engines_config-2)/c_offset_between_descriptors),  // input wire [9 : 0] addrb
    .web  (8'b0                     ), // input wire [0 : 0] web
    .dinb (64'b0                    ), // input wire [63 : 0] dinb
    .doutb(doutb_req_bytes_s        )  // output wire [63 : 0] doutb
  );
  blk_mem_descriptor blk_mem_descriptor_comp_bytes (
    .clka (CLK                      ), // input wire clka
    .ena  (ena_time_r               ), // input wire ena
    .wea  (wea_time_r               ), // input wire [7 : 0] wea
    .addra(active_index_descriptor_r), // input wire [9 : 0] addra
    .dina (dina_comp_bytes_r        ), // input wire [63 : 0] dina
    .douta(douta_comp_bytes_s       ), // output wire [63 : 0] douta
    .clkb (CLK                      ), // input wire clkb
    .enb  (1'b1                     ), // input wire enb
    .addrb(addra_comp_bytes_r       ), //(S_MEM_IFACE_ADDR-i*C_OFFSET_BETWEEN_ENGINES-c_offset_engines_config-2)/c_offset_between_descriptors),  // input wire [9 : 0] addrb
    .web  (8'b0                     ), // input wire [0 : 0] web
    .dinb (64'b0                    ), // input wire [63 : 0] dinb
    .doutb(doutb_comp_bytes_s       )  // output wire [63 : 0] doutb
  );

  wire [                                    31:0] effective_addres_s      ;
  wire [$clog2(c_offset_between_descriptors)-1:0] effective_addres_trunc_s;
  assign effective_addres_s       = (S_MEM_IFACE_ADDR-C_ENGINE_TABLE_OFFSET - c_offset_engines_config);
  assign effective_addres_trunc_s = effective_addres_s[$clog2(c_offset_between_descriptors)-1:0];
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      ena_size_r    <= 1'b0;
      wea_size_r    <= {8{1'b0}};
      ena_address_r <= 1'b0;
      wea_address_r <= {8{1'b0}};
      ena_control_r <= 1'b0;
      wea_control_r <= {8{1'b0}};
      ena_time_r    <= 1'b0;
      wea_time_r    <= {8{1'b0}};
    end else begin
      if(UPDATE_LATENCY) begin
        ena_size_r    <= 1'b0;
        ena_address_r <= 1'h0;
        ena_control_r <= 1'h0;
        ena_time_r    <= 1'h1;
        wea_time_r    <= 8'hff;
      end else if(S_MEM_IFACE_EN && effective_addres_s <= c_offset_between_descriptors*C_NUM_DESCRIPTORS) begin // If we are writing and this transaction correspond to the current engine
        wea_size_r    <= S_MEM_IFACE_WE;
        wea_address_r <= S_MEM_IFACE_WE;
        wea_control_r <= S_MEM_IFACE_WE;
        wea_time_r    <= 8'h0;

        case(effective_addres_trunc_s)
          0 : begin
            ena_size_r    <= 1'h0;
            ena_address_r <= 1'h1;
            ena_control_r <= 1'h0;
            ena_time_r    <= 1'h0;
          end
          1 : begin
            ena_size_r    <= 1'h1;
            ena_address_r <= 1'h0;
            ena_control_r <= 1'h0;
            ena_time_r    <= 1'h0;
          end
          2 : begin
            ena_size_r    <= 1'h0;
            ena_address_r <= 1'h0;
            ena_control_r <= 1'h1;
            ena_time_r    <= 1'h0;
          end
          default : begin
            ena_size_r    <= 1'h0;
            ena_address_r <= 1'h0;
            ena_control_r <= 1'h0;
            ena_time_r    <= 1'h0;
          end
        endcase
      end else begin
        ena_size_r    <= 1'h0;
        ena_address_r <= 1'h0;
        ena_control_r <= 1'h0;
        ena_time_r    <= 1'h0;
      end
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      dina_size_r       <= 64'h0;
      dina_address_r    <= 64'h0;
      dina_control_r    <= 64'h0;
      dina_time_r       <= 64'h0;
      dina_req_time_r   <= 64'h0;
      dina_comp_time_r  <= 64'h0;
      dina_req_bytes_r  <= 64'h0;
      dina_comp_bytes_r <= 64'h0;
    end else begin
      dina_size_r       <= S_MEM_IFACE_DIN;
      dina_address_r    <= S_MEM_IFACE_DIN;
      dina_control_r    <= S_MEM_IFACE_DIN;
      dina_time_r       <= CURRENT_LATENCY;
      dina_req_time_r   <= TIME_AT_REQ;
      dina_comp_time_r  <= TIME_AT_COMP;
      dina_req_bytes_r  <= BYTES_AT_REQ;
      dina_comp_bytes_r <= BYTES_AT_COMP;
    end
  end

  // Index at word level:
  //    Position 0  -  Descriptor 0
  //    Position 1  -  Descriptor 1
  //                .
  //                .
  //                .
  //    Position i  -  Descriptor i
  //                .
  //                .
  //
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      addra_size_r       <= {`CLOG2(C_NUM_DESCRIPTORS){1'b0}};
      addra_address_r    <= {`CLOG2(C_NUM_DESCRIPTORS){1'b0}};
      addra_control_r    <= {`CLOG2(C_NUM_DESCRIPTORS){1'b0}};
      addra_time_r       <= {`CLOG2(C_NUM_DESCRIPTORS){1'b0}};
      addra_req_time_r   <= {`CLOG2(C_NUM_DESCRIPTORS){1'b0}};
      addra_comp_time_r  <= {`CLOG2(C_NUM_DESCRIPTORS){1'b0}};
      addra_req_bytes_r  <= {`CLOG2(C_NUM_DESCRIPTORS){1'b0}};
      addra_comp_bytes_r <= {`CLOG2(C_NUM_DESCRIPTORS){1'b0}};
    end else begin
      addra_size_r       <= (S_MEM_IFACE_ADDR-C_ENGINE_TABLE_OFFSET-c_offset_engines_config-1)/c_offset_between_descriptors;
      addra_address_r    <= (S_MEM_IFACE_ADDR-C_ENGINE_TABLE_OFFSET-c_offset_engines_config)/c_offset_between_descriptors;
      addra_control_r    <= (S_MEM_IFACE_ADDR-C_ENGINE_TABLE_OFFSET-c_offset_engines_config-2)/c_offset_between_descriptors;
      addra_time_r       <= (S_MEM_IFACE_ADDR-C_ENGINE_TABLE_OFFSET-c_offset_engines_config-3)/c_offset_between_descriptors;
      addra_req_time_r   <= (S_MEM_IFACE_ADDR-C_ENGINE_TABLE_OFFSET-c_offset_engines_config-4)/c_offset_between_descriptors;
      addra_comp_time_r  <= (S_MEM_IFACE_ADDR-C_ENGINE_TABLE_OFFSET-c_offset_engines_config-5)/c_offset_between_descriptors;
      addra_req_bytes_r  <= (S_MEM_IFACE_ADDR-C_ENGINE_TABLE_OFFSET-c_offset_engines_config-6)/c_offset_between_descriptors;
      addra_comp_bytes_r <= (S_MEM_IFACE_ADDR-C_ENGINE_TABLE_OFFSET-c_offset_engines_config-7)/c_offset_between_descriptors;
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      rdata_descriptor_r <= {C_DATA_WIDTH{1'b0}};
    end else begin
      case(effective_addres_trunc_s)
        0 : begin
          rdata_descriptor_r <= doutb_address_s;
        end
        1 : begin
          rdata_descriptor_r <= douta_size_s;
        end
        2 : begin
          rdata_descriptor_r <= doutb_control_s;
        end
        3 : begin
          rdata_descriptor_r <= doutb_time_s;
        end
        4 : begin
          rdata_descriptor_r <= doutb_req_time_s;
        end
        5 : begin
          rdata_descriptor_r <= doutb_comp_time_s;
        end
        6 : begin
          rdata_descriptor_r <= doutb_req_bytes_s;
        end
        7 : begin
          rdata_descriptor_r <= doutb_comp_bytes_s;
        end
      endcase
    end
  end

  // Read logic from regs
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      rdata_engine_r   <= {C_DATA_WIDTH{1'b0}};
      is_engine_read_r <= 1'b0;
    end else begin
      if(S_MEM_IFACE_EN) begin
        case(S_MEM_IFACE_ADDR)
          C_ENGINE_TABLE_OFFSET : begin  // Control byte of DMA engine
            rdata_engine_r   <= { {C_DATA_WIDTH-7{1'b0}},capabilities_r[1:0],error_r, stop_r,running_r,reset_r,enable_r};
            is_engine_read_r <= 1'b1;
          end
          C_ENGINE_TABLE_OFFSET  + 1: begin
            rdata_engine_r   <= {{C_DATA_WIDTH-2*`CLOG2(C_NUM_DESCRIPTORS){1'h0}},active_index_descriptor_r,last_index_descriptor_r};
            is_engine_read_r <= 1'b1;
          end
          C_ENGINE_TABLE_OFFSET  + 2: begin
            rdata_engine_r   <= time_r;
            is_engine_read_r <= 1'b1;
          end
          C_ENGINE_TABLE_OFFSET  + 3: begin
            rdata_engine_r   <= byte_count_r;
            is_engine_read_r <= 1'b1;
          end
          default : begin
            rdata_engine_r   <= {C_DATA_WIDTH{1'b0}};
            is_engine_read_r <= 1'b0;
          end
        endcase
      end
    end
  end


  // Counters.
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      time_r       <= 64'h00;
      byte_count_r <= 64'h00;
      running_r    <= 1'b0;
    end else begin
      if(cl_engine_stats_r) begin
        time_r       <= 64'h00;
        byte_count_r <= 64'h00;
        running_r    <= 1'b0;
      end else if(enable_r && !stop_r) begin
        time_r       <= time_r + 1;
        byte_count_r <= byte_count_r + BYTE_COUNT;
      end else begin
        time_r       <= time_r;
        byte_count_r <= byte_count_r;
      end
      running_r <= enable_r & !stop_r;
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      stop_r        <= 1'b0;
      error_r       <= 1'b0;
    end else begin
      if( cl_engine_stats_r ) begin
        stop_r        <= 1'b0;
        error_r       <= 1'b0;
      end else begin
        stop_r        <= is_end_of_operation_s && (active_index_descriptor_r == last_index_descriptor_r) ? 1'b1 : 1'b0;
        error_r       <= operation_error_s;
      end
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      active_index_descriptor_r <= 0;
    end else begin
      if( is_end_of_operation_s) begin
        if(active_index_descriptor_r == C_NUM_DESCRIPTORS-1) begin
          active_index_descriptor_r <= 0;
        end else begin
          active_index_descriptor_r <= active_index_descriptor_r + 1;
        end
      end else begin
        active_index_descriptor_r <= active_index_descriptor_r;
      end
    end
  end

  assign IRQ = 0;

endmodule

