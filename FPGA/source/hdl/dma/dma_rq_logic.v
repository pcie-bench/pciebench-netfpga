/**
@class dma_rq_logic

@author      Jose Fernando Zazo Rollon (josefernando.zazo@estudiante.uam.es)
@date        04/05/2015

@brief Design containing  the DMA requester interface


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


In this particular module
mem_wr_* references a memory write request signal
mem_rd_* references a memory read request signal

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

module dma_rq_logic #(
  parameter C_BUS_DATA_WIDTH        = 256,
  parameter                                           C_BUS_KEEP_WIDTH = (C_BUS_DATA_WIDTH/32),
  parameter                                           C_AXI_KEEP_WIDTH = (C_BUS_DATA_WIDTH/8),
  parameter C_WINDOW_SIZE           = 16 ,
  parameter C_LOG2_MAX_PAYLOAD      = 8  , // 2**C_LOG2_MAX_PAYLOAD in bytes
  parameter C_LOG2_MAX_READ_REQUEST = 14   // 2**C_LOG2_MAX_READ_REQUEST in bytes
) (
  input  wire                        CLK                      ,
  input  wire                        RST_N                    ,
  ////////////
  //  PCIe Interface: 1 AXI-Stream (requester side)
  ////////////
  output wire [C_BUS_DATA_WIDTH-1:0] M_AXIS_RQ_TDATA          ,
  output wire [                59:0] M_AXIS_RQ_TUSER          ,
  output wire                        M_AXIS_RQ_TLAST          ,
  output wire [C_BUS_KEEP_WIDTH-1:0] M_AXIS_RQ_TKEEP          ,
  output wire                        M_AXIS_RQ_TVALID         ,
  input  wire [                 3:0] M_AXIS_RQ_TREADY         ,
  input  wire [C_BUS_DATA_WIDTH-1:0] S_AXIS_RC_TDATA          ,
  input  wire [                74:0] S_AXIS_RC_TUSER          ,
  input  wire                        S_AXIS_RC_TLAST          ,
  input  wire [C_BUS_KEEP_WIDTH-1:0] S_AXIS_RC_TKEEP          ,
  input  wire                        S_AXIS_RC_TVALID         ,
  input  wire [                21:0] S_AXIS_RC_TREADY         ,
  ////////////
  //  c2s fifo interface: 1 AXI-Stream (data to be transferred in memory write requests)
  ////////////
  output wire                        C2S_FIFO_TREADY          ,
  input  wire [C_BUS_DATA_WIDTH-1:0] C2S_FIFO_TDATA           ,
  input  wire                        C2S_FIFO_TLAST           ,
  input  wire                        C2S_FIFO_TVALID          ,
  input  wire [C_AXI_KEEP_WIDTH-1:0] C2S_FIFO_TKEEP           ,
  ////////////
  //  Descriptor interface: Interface with the necessary data to complete a memory read/write request.
  ////////////
  input  wire                        ENGINE_VALID             ,
  input  wire [                 7:0] STATUS_BYTE              ,
  output wire [                 7:0] CONTROL_BYTE             ,
  output reg  [                63:0] BYTE_COUNT               ,
  input  wire [                63:0] SIZE_AT_DESCRIPTOR       ,
  input  wire [                63:0] ADDR_AT_DESCRIPTOR       ,
  input  wire [                63:0] DESCRIPTOR_MAX_TIMEOUT   ,
  output wire                        HW_REQUEST_TRANSFERENCE  ,
  output wire [                63:0] HW_NEW_SIZE_AT_DESCRIPTOR,
  output wire                        UPDATE_LATENCY           ,
  output wire [                63:0] CURRENT_LATENCY          ,
  output wire [                63:0] TIME_AT_REQ              ,
  output wire [                63:0] TIME_AT_COMP             ,
  output wire [                63:0] BYTES_AT_REQ             ,
  output wire [                63:0] BYTES_AT_COMP            ,
  output wire [                63:0] WORD_COUNT               ,
  output wire [   C_WINDOW_SIZE-1:0] BUSY_TAGS                ,
  output wire [C_WINDOW_SIZE*11-1:0] SIZE_TAGS                , //Size associate to each tag
  input  wire [   C_WINDOW_SIZE-1:0] COMPLETED_TAGS           ,
  input  wire [                63:0] CURRENT_WINDOW_SIZE      ,
  output wire [                63:0] DEBUG
);
  localparam c_req_attr = 3'b000; //ID based ordering, Relaxed ordering, No Snoop
  localparam c_req_tc   = 3'b000;

  wire [63:0] adapted_size_at_descriptor_s;
  assign adapted_size_at_descriptor_s = ADDR_AT_DESCRIPTOR[1:0] ? SIZE_AT_DESCRIPTOR+4:SIZE_AT_DESCRIPTOR; 



  ////////////
  //  c2s fifo management
  ////////////
  /*

  The data that is previously stored in a fifo (AXI Stream FIFO), is
  read and stored in a circular buffer. It simplifies the process of
  manage VALID and READY signals in the protocol.

  */
  wire [               255:0] c2s_fifo_tdata_s;
  wire [C_AXI_KEEP_WIDTH-1:0] c2s_fifo_tkeep_s;

  wire         c2s_fifo_tready_s      ;
  wire         c2s_fifo_tlast_s       ;
  wire         c2s_fifo_tvalid_s      ;
  reg  [127:0] c2s_buffer       [0:15];
  wire [  4:0] c2s_buf_occupancy      ;
  wire         c2s_buf_full           ;
  reg  [  4:0] c2s_buf_rd_ptr         ;
  reg  [  4:0] c2s_buf_wr_ptr         ;



  wire                        c2s_proc_tready_s;
  wire [C_BUS_DATA_WIDTH-1:0] c2s_proc_tdata_s ;
  wire                        c2s_proc_tlast_s ;
  wire                        c2s_proc_tvalid_s;
  wire [C_AXI_KEEP_WIDTH-1:0] c2s_proc_tkeep_s ;



  assign c2s_proc_tready_s = c2s_fifo_tready_s;
  assign c2s_fifo_tkeep_s  = c2s_proc_tkeep_s;

  assign c2s_fifo_tdata_s  = c2s_proc_tdata_s;
  assign c2s_fifo_tlast_s  = c2s_proc_tlast_s;
  assign c2s_fifo_tvalid_s = c2s_proc_tvalid_s;

  assign c2s_buf_occupancy = c2s_buf_wr_ptr - c2s_buf_rd_ptr;
  assign c2s_buf_full      = c2s_buf_occupancy[4];
  assign c2s_fifo_tready_s = c2s_buf_occupancy <= 12;

  function [3:0] trunc(input [4:0] value);
    trunc = value[3:0];
  endfunction


  integer i;
  always @(negedge RST_N or posedge CLK) begin
    if (!RST_N) begin
      c2s_buf_wr_ptr <= 4'b0;
      for(i=0; i<16;i=i+1)
        c2s_buffer[i] <= 128'h0;
    end else begin
      if (c2s_fifo_tvalid_s && c2s_fifo_tready_s) begin
        c2s_buffer[trunc(c2s_buf_wr_ptr)]   <= c2s_fifo_tdata_s[127:0];
        c2s_buffer[trunc(c2s_buf_wr_ptr+1)] <= c2s_fifo_tdata_s[255:128];

        if(c2s_fifo_tkeep_s[C_AXI_KEEP_WIDTH/2]) begin // The two 64b words are valid
          c2s_buf_wr_ptr <= c2s_buf_wr_ptr + 2;
        end else begin                                 // just one word is valid
          c2s_buf_wr_ptr <= c2s_buf_wr_ptr + 1;
        end
      end
    end
  end

  assign c2s_buf_occupancy = c2s_buf_wr_ptr - c2s_buf_rd_ptr;
  assign c2s_buf_full      = c2s_buf_occupancy[4];


  ////////////
  //  End of C2S fifo management.
  ////////////

  reg [C_BUS_DATA_WIDTH-1:0] axis_rq_tdata_r ;
  reg                        axis_rq_tlast_r ;
  reg [C_BUS_KEEP_WIDTH-1:0] axis_rq_tkeep_r ;
  reg                        axis_rq_tvalid_r;
  reg [                 3:0] first_be_r      ;
  reg [                 3:0] last_be_r       ;



  wire [63:0] log2_max_words_tlp_s;
  wire [63:0] max_words_tlp_s     ;
  assign log2_max_words_tlp_s = C_LOG2_MAX_PAYLOAD-2; // "Words" refers to 4 byte
  assign max_words_tlp_s      = { {64-C_LOG2_MAX_PAYLOAD-1{1'b0}},1'b1, {C_LOG2_MAX_PAYLOAD-2{1'b0}} }; //(1<<(C_LOG2_MAX_PAYLOAD-2)); //32  bit words

  wire [63:0] log2_max_words_read_request_s;
  wire [63:0] max_words_read_request_s     ;
  assign log2_max_words_read_request_s = C_LOG2_MAX_READ_REQUEST-2; //32 (2**5) bit words
  assign max_words_read_request_s      = { {64-C_LOG2_MAX_READ_REQUEST-1{1'b0}},1'b1, {C_LOG2_MAX_READ_REQUEST-2{1'b0}} }; // (1<<(C_LOG2_MAX_READ_REQUEST-2)); //32 (2**5) bit words


  reg [15:0] state                              ;
  reg [15:0] wr_state                           ;
  reg [31:0] mem_wr_current_tlp_r               ; //Current TLP.
  reg [31:0] mem_rd_current_tlp_r               ; //Current TLP.
  reg [63:0] mem_wr_total_words_r               ; //Total number of 4-bytes words to transfer
  reg [63:0] mem_rd_total_words_r               ; //Total number of 4-bytes words to transfer
  reg [63:0] mem_wr_remaining_words_r           ; // Total number of 4-bytes words in the current TLP
  reg [63:0] mem_rd_remaining_words_r           ; // Total number of 4-bytes words in the current TLP
  reg [ 3:0] mem_wr_next_remainder_r            ;
  reg [31:0] mem_wr_total_tlp_r                 ; // Total number of TLPs to communicate
  reg [31:0] mem_rd_total_tlp_r                 ; // Total number of TLPs to communicate
  reg [63:0] mem_wr_last_tlp_words_r            ; // Words in the last TLP, the rest will have the maximum size
  reg [63:0] mem_wr_middle_tlp_words_r          ; // Words in the middle TLPs, maximum size or just one tlp
  reg [63:0] mem_rd_middle_tlp_words_r          ; // Words in the middle TLPs, maximum size or just one tlp
  reg [63:0] mem_rd_last_tlp_words_r            ; // Words in the last TLP, the rest will have the maximum size
  reg [63:0] mem_wr_addr_pointed_by_descriptor_r; // Region communicated by the user in the descriptor
  reg [63:0] mem_rd_addr_pointed_by_descriptor_r; // Region communicated by the user in the descriptor
  reg [15:0] wr_state_pipe_r                    ; // Previous value of the state wr_state

  assign DEBUG = { state,mem_wr_total_tlp_r[15:0], wr_state, mem_wr_current_tlp_r[15:0] };

  // States of the FSMs.
  localparam IDLE       = 16'h0;
  localparam INIT_WRITE = 16'h1;
  localparam WRITE      = 16'h2;
  localparam INIT_READ  = 16'h3;
  localparam WAIT_READ  = 16'h4;
  localparam WAIT_RD_OP = 16'h5;
  localparam WAIT_WR_OP = 16'h6;




  //"Capabilities_s" indicates if the engine will generate memory write requests o memory read requests
  wire [1:0] capabilities_s;
  assign capabilities_s = STATUS_BYTE[6:5];

  reg [C_WINDOW_SIZE-1:0] current_tags_r; // Number of asked tags (memory read) that hasnt been received yet.
  wire end_of_operation;
  reg end_of_operation_r;

  reg [C_WINDOW_SIZE-1:0] window_size_mask_r;
  reg [              7:0] window_size_r     ;

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      window_size_mask_r <= 'h0;
      window_size_r      <= 'h0;
    end else begin
      window_size_r      <= CURRENT_WINDOW_SIZE[7:0];
      window_size_mask_r <= dec2mask(window_size_r);
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      end_of_operation_r <= 0;
    end else begin
      end_of_operation_r <= end_of_operation;
    end
  end
  assign end_of_operation = (wr_state==WAIT_READ && ((current_tags_r & window_size_mask_r)=={C_WINDOW_SIZE{1'b0}}))
    || (wr_state == IDLE && (wr_state_pipe_r==INIT_WRITE||wr_state_pipe_r==WRITE));
  assign CONTROL_BYTE = {4'h0, end_of_operation, 3'h0 }; // Waiting completer, Stop will coincide with tlast


  /*
  Main FSM where a selected engine is treated. There are three FSMs:
  a) IDLE, WAIT_RD_OP, WAIT_WR_OP:
  Just indicates which action is being taken.
  b) IDLE, INIT_WRITE, WRITE:
  In a memory write request:
  IDLE       -> Do nothing.
  INIT_WRITE -> Specify the TLP header and the first 128 bits of data
  WIRTE      -> The rest of the package
  c) INIT_READ, WAIT_READ:
  In a memory read request:
  IDLE       -> Do nothing.
  INIT_READ  -> Specify the TLP header if the tag is not busy. Repeat until all the request has been processed.
  WAIT_READ  -> Wait for all the TLPs of a memory read request.
  */

  reg [31:0] byte_en_r    ;
  reg        is_sop_r     ;
  reg [ 1:0] addr_offset_r;

  assign M_AXIS_RQ_TDATA  = axis_rq_tdata_r;
  assign M_AXIS_RQ_TUSER  = {50'h0,addr_offset_r, last_be_r, first_be_r};
  assign M_AXIS_RQ_TLAST  = axis_rq_tlast_r;
  assign M_AXIS_RQ_TKEEP  = axis_rq_tkeep_r;
  assign M_AXIS_RQ_TVALID = axis_rq_tvalid_r;

  reg [7:0] req_tag_r; // Current tag for a memory read request (for memory writes let the
  // EP to choose it automatically).
  reg  [C_WINDOW_SIZE-1:0] req_tag_oh_r; // Same as req_tag_r but in one hot codification
  wire [              7:0] c2s_rq_tag_s; // Number of asked tags (memory read) that hasnt been received yet.
  wire [              7:0] s2c_rq_tag_s;



  genvar        j                             ;
  reg    [10:0] size_tags_r[C_WINDOW_SIZE-1:0]; // Number of expected dwords (for each tag)
  // Verilog doesnt let us to communicate an array to the external world. We express it as a big vector.
  for(j=0; j<C_WINDOW_SIZE;j=j+1) begin
    assign SIZE_TAGS[11*(j+1)-1:11*j] = size_tags_r[j];
  end

  function [7:0] bit2pos(input [C_WINDOW_SIZE-1:0] oh);
    integer k;
    begin
      bit2pos = 0;
      for (k=0; k<C_WINDOW_SIZE; k=k+1) begin
        if (oh[k]) bit2pos = k;
      end
    end
  endfunction

  function [C_WINDOW_SIZE-1:0] dec2mask(input [7:0] dec);
    integer k;
    begin
      dec2mask = 0;
      for (k=0; k<C_WINDOW_SIZE; k=k+1) begin
        if (k<dec) begin
          dec2mask[k] = 1;
        end
      end
    end
  endfunction
  ////////
  // Logic that creates the Memory Write request TLPs (header and  data).
  // DATA and VALID signals are given value in this process
  reg [C_WINDOW_SIZE-1:0] pending_error_r;

  wire last_word_at_tlp_s     ;
  wire last_two_words_at_tlp_s;
  wire one_word_at_buffer_s   ;
  wire two_words_at_buffer_s  ;

  assign last_word_at_tlp_s      = mem_wr_remaining_words_r <= 4;
  assign last_two_words_at_tlp_s = mem_wr_remaining_words_r <= 8;
  assign one_word_at_buffer_s    = c2s_buf_occupancy!=0;
  assign two_words_at_buffer_s   = c2s_buf_occupancy[4:1]!=0;

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      axis_rq_tvalid_r <= 1'b0;
      axis_rq_tdata_r  <= {C_BUS_DATA_WIDTH{1'b0}};
      c2s_buf_rd_ptr   <= 5'h0;
    end else begin
      case(wr_state)
        INIT_WRITE : begin // A TLP of type memory write has to be requested.
          if(M_AXIS_RQ_TREADY) begin
            // we are not looking for the descriptor. Configure ir properly when the s2c is completed.

            axis_rq_tdata_r <= {c2s_buffer[trunc(c2s_buf_rd_ptr)], //128 bits data
              //DW 3
              1'b0,      //Force ECRC insertion 31 - 1 bit reserved          127
              c_req_attr,//30-28 3 bits Attr          124-126
              c_req_tc,  // 27-25 3- bits         121-123
              1'b0,      // Use bus and req id from the EP          120
              16'h0000,  //xcompleter_id_bus,    // 23-16 Completer Bus number - selected if Compl ID    = 1  104-119
              //completer_id_dev_func, //15-8 Compl Dev / Func no - sel if Compl ID = 1
              c2s_rq_tag_s,  //req_tag 7-0 Client Tag 96-103
              //DW 2
              16'h0000,  // 31-16 Bus number - 16 bits Requester ID 80-95
              // (optional fields, the endpoints IDs will be used if no id is specified)
              1'b0,      // poisoned request 1'b0,          // 15 Rsvd    79
              4'b0001,   // memory WRITE request      75-78
              mem_wr_remaining_words_r[10:0],  // 10-0 DWord Count 0 - IO Write completions -64-74
              //DW 1-0
              mem_wr_addr_pointed_by_descriptor_r[63:2], 2'b00};  //62 bit word address address + 2 bit Address type (0, untranslated)

            if(one_word_at_buffer_s) begin
              c2s_buf_rd_ptr   <= c2s_buf_rd_ptr + 1;
              axis_rq_tvalid_r <= 1'b1;
            end else begin
              axis_rq_tvalid_r <= 1'b0;
            end
          end else begin
            axis_rq_tvalid_r <= axis_rq_tvalid_r;
            axis_rq_tdata_r  <= axis_rq_tdata_r;
          end
        end

        WRITE : begin // A TLP of type memory write has to be requested.
          if( M_AXIS_RQ_TREADY) begin // Wait for the "ACK" of the previous TLP
            if( one_word_at_buffer_s && last_word_at_tlp_s ) begin
              axis_rq_tdata_r  <= {128'h0, c2s_buffer[trunc(c2s_buf_rd_ptr)]};
              c2s_buf_rd_ptr   <= c2s_buf_rd_ptr + 1;
              axis_rq_tvalid_r <= 1'b1;
            end else if( two_words_at_buffer_s ) begin
              axis_rq_tdata_r  <= {c2s_buffer[trunc(c2s_buf_rd_ptr+1)], c2s_buffer[trunc(c2s_buf_rd_ptr)]};
              c2s_buf_rd_ptr   <= c2s_buf_rd_ptr + 2;
              axis_rq_tvalid_r <= 1'b1;
            end else begin
              axis_rq_tvalid_r <= 1'b0;
            end
          end else begin
            axis_rq_tdata_r  <= axis_rq_tdata_r;
            axis_rq_tvalid_r <= axis_rq_tvalid_r;
          end
        end

        INIT_READ : begin
          if(M_AXIS_RQ_TREADY && (mem_rd_current_tlp_r<= mem_rd_total_tlp_r) &&  (current_tags_r & window_size_mask_r)!=window_size_mask_r) begin
            //DW 7-4
            axis_rq_tdata_r <= { 128'h0, //128 bits data
              //DW 3
              1'b0,      //31 - 1 bit reserved
              c_req_attr, //30-28 3 bits Attr
              c_req_tc,   // 27-25 3- bits
              1'b0,      // 24 req_id enable
              16'h0,  //xcompleter_id_bus,     -- 23-16 Completer Bus number - selected if Compl ID    = 1
              //completer_id_dev_func, --15-8 Compl Dev / Func no - sel if Compl ID = 1
              s2c_rq_tag_s,  // 7-0 Client Tag
              //DW 2
              16'h0000, //req_rid,       -- 31-16 Requester ID - 16 bits
              1'b0,      // poisoned request 1'b0,          -- 15 Rsvd
              4'b0000,   // memory READ request
              mem_rd_remaining_words_r[10:0],  // 10-0 DWord Count 0 - IO Write completions
              //DW 1-0
              mem_rd_addr_pointed_by_descriptor_r[63:2],2'b00 }; //62 bit word address address + 2 bit Address type (0, untranslated)

            axis_rq_tvalid_r <= 1'b1;
          end else if(!M_AXIS_RQ_TREADY) begin
            axis_rq_tvalid_r <= axis_rq_tvalid_r;
            axis_rq_tdata_r  <= axis_rq_tdata_r;
          end else begin
            axis_rq_tvalid_r <= 1'b0;
          end
        end
        default : begin
          if(M_AXIS_RQ_TREADY) begin
            axis_rq_tvalid_r <= 1'b0;
            axis_rq_tdata_r  <= {C_BUS_DATA_WIDTH{1'b0}};
          end else begin
            axis_rq_tvalid_r <= axis_rq_tvalid_r;
            axis_rq_tdata_r  <= axis_rq_tdata_r;
          end
        end

      endcase
    end
  end

  // Logic that counts the number of bytes transferred (memory write request).
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      BYTE_COUNT <= 64'h0;
    end else begin
      BYTE_COUNT <= BYTE_COUNT;
    end
  end


  ////////
  // Logic that manages KEEP and LAST signals. Large and tedious but simple in logic.
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      addr_offset_r <= 2'h0;
    end else begin
      addr_offset_r <= capabilities_s[0] ? mem_wr_addr_pointed_by_descriptor_r[1:0] : mem_rd_addr_pointed_by_descriptor_r[1:0];
    end
  end


  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      axis_rq_tkeep_r <= {C_BUS_KEEP_WIDTH{1'b0}};
      axis_rq_tlast_r <= 1'b0;
      first_be_r      <= 4'h0;
      last_be_r       <= 4'h0;
    end else begin
      is_sop_r <= 1'b0;

      if(M_AXIS_RQ_TREADY && wr_state == INIT_WRITE) begin // A TLP of type memory write has to be requested.
        is_sop_r <= 1'b1;
        case(addr_offset_r) // Unaligned offset
          2'b01   : begin  first_be_r   <= 4'b1110; end
          2'b10   : begin  first_be_r   <= 4'b1100; end
          2'b11   : begin  first_be_r   <= 4'b1000; end
          default : first_be_r   <= 4'b1111;
        endcase
        if(mem_wr_remaining_words_r <= 1) begin
          last_be_r <= 4'h0; // First word and last are the same, so last_be = 0
        end else if(mem_wr_current_tlp_r!=mem_wr_total_tlp_r) begin
          last_be_r <= 4'b1111;
        end else begin
          case(addr_offset_r) // Unaligned offset
            2'b01   : begin last_be_r  <= 4'b0001; end
            2'b10   : begin last_be_r  <= 4'b0011; end
            2'b11   : begin last_be_r  <= 4'b0111; end
            default : last_be_r   <= 4'b1111;
          endcase
        end
        if( M_AXIS_RQ_TREADY && one_word_at_buffer_s ) begin
          if(last_word_at_tlp_s) begin
            axis_rq_tlast_r <= 1'b1;

            axis_rq_tkeep_r <= mem_wr_next_remainder_r==0 ? 8'h0f :
              mem_wr_next_remainder_r == 1 ? 8'h1f :
              mem_wr_next_remainder_r == 2 ? 8'h3f :
              mem_wr_next_remainder_r == 3 ? 8'h7f : 8'hff;
          end else begin
            axis_rq_tkeep_r <= 8'hff;
            axis_rq_tlast_r <= 1'b0;
          end
        end else begin
          axis_rq_tkeep_r <= axis_rq_tkeep_r;
          axis_rq_tlast_r <= axis_rq_tlast_r;
        end
      end else if(M_AXIS_RQ_TREADY && wr_state == WRITE) begin // A TLP of type memory write has to be requested.
        if(M_AXIS_RQ_TREADY && ((two_words_at_buffer_s && last_two_words_at_tlp_s) || (one_word_at_buffer_s && last_word_at_tlp_s))) begin
          axis_rq_tlast_r <= last_two_words_at_tlp_s;


          axis_rq_tkeep_r <= mem_wr_next_remainder_r==0 ? 8'h00 :
            mem_wr_next_remainder_r == 1 ? 8'h01 :
            mem_wr_next_remainder_r == 2 ? 8'h03 :
            mem_wr_next_remainder_r == 3 ? 8'h07 :
            mem_wr_next_remainder_r == 4 ? 8'h0f :
            mem_wr_next_remainder_r == 5 ? 8'h1f :
            mem_wr_next_remainder_r == 6 ? 8'h3f :
            mem_wr_next_remainder_r == 7 ? 8'h7f : 8'hff;
        end else begin
          axis_rq_tlast_r <= axis_rq_tlast_r;
        end
      end else if( M_AXIS_RQ_TREADY && wr_state == INIT_READ ) begin
        axis_rq_tkeep_r <= 8'h0f;
        axis_rq_tlast_r <= 1'b1;

        if(mem_rd_remaining_words_r[10:1] == 0) begin
          last_be_r <= 4'h0; // First word and last are the same, so last_be = 0
        end else if(mem_rd_current_tlp_r!=mem_rd_total_tlp_r) begin
          last_be_r <= 4'b1111;
        end else begin
          first_be_r <= 4'b1111;
          case(addr_offset_r) // Unaligned offset
            2'b01   : begin last_be_r  <= 4'b0001; end
            2'b10   : begin last_be_r  <= 4'b0011; end
            2'b11   : begin last_be_r  <= 4'b0111; end
            default : last_be_r   <= 4'b1111;
          endcase
        end

        if(mem_rd_current_tlp_r==1) begin
          case(addr_offset_r)
            2'b01   : begin  first_be_r   <= 4'b1110; end
            2'b10   : begin  first_be_r   <= 4'b1100; end
            2'b11   : begin  first_be_r   <= 4'b1000; end
            default : first_be_r   <= 4'b1111;
          endcase
        end else if(mem_rd_current_tlp_r==mem_rd_total_tlp_r && mem_rd_remaining_words_r[10:1] == 0) begin
          case(addr_offset_r)
            2'b01   : begin  first_be_r   <= 4'b0001; end
            2'b10   : begin  first_be_r   <= 4'b0011; end
            2'b11   : begin  first_be_r   <= 4'b0111; end
            default : first_be_r   <= 4'b1111;
          endcase
        end else begin
          first_be_r <= 4'b1111;
        end
      end else begin
        axis_rq_tkeep_r <= axis_rq_tkeep_r;
        axis_rq_tlast_r <= axis_rq_tlast_r;
      end
    end
  end


  ////////
  // Get the total numbers of words and the total numer of TLPs in a transition
  always @(negedge RST_N or posedge CLK) begin
    if (!RST_N) begin
      mem_wr_total_tlp_r      <= 32'b0;
      mem_wr_total_words_r    <= 64'b0;
      mem_wr_last_tlp_words_r <= 64'h0;
    end else begin
      if(ENGINE_VALID && !end_of_operation_r && !end_of_operation  && capabilities_s[0] ) begin
        mem_wr_total_words_r <= adapted_size_at_descriptor_s[63:2];

        if(adapted_size_at_descriptor_s[C_LOG2_MAX_PAYLOAD-1:0] > 0) begin // Get the modulus 2**(log2_max_words_tlp_s)
          mem_wr_total_tlp_r      <= (adapted_size_at_descriptor_s>>(log2_max_words_tlp_s+2))  + 1; // Express size at descriptor as 32 bit word.
          mem_wr_last_tlp_words_r <= ((adapted_size_at_descriptor_s&{C_LOG2_MAX_PAYLOAD{1'b1}}) >> 2) ;
        end else begin
          mem_wr_total_tlp_r      <= adapted_size_at_descriptor_s>>(log2_max_words_tlp_s+2);
          mem_wr_last_tlp_words_r <= max_words_tlp_s;
        end
     // end else if(ENGINE_VALID &&  (ENGINE_VALID  !end_of_operation_r) begin
     //   mem_wr_total_tlp_r <= 32'b0;
      end else if(ENGINE_VALID && (end_of_operation_r||end_of_operation)) begin
        mem_wr_total_tlp_r <= 32'b0;
      end else begin
        mem_wr_total_tlp_r      <= mem_wr_total_tlp_r;
        mem_wr_total_words_r    <= mem_wr_total_words_r;
        mem_wr_last_tlp_words_r <= mem_wr_last_tlp_words_r;
      end
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if (!RST_N) begin
      mem_wr_middle_tlp_words_r <= 64'h0;
    end else begin
      mem_wr_middle_tlp_words_r <= adapted_size_at_descriptor_s[63:2] <= max_words_tlp_s ? adapted_size_at_descriptor_s[63:2]  : max_words_tlp_s;
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if (!RST_N) begin
      mem_rd_total_tlp_r      <= 32'b0;
      mem_rd_total_words_r    <= 64'b0;
      mem_rd_last_tlp_words_r <= 64'h0;
    end else begin
      if(ENGINE_VALID && !end_of_operation_r && !end_of_operation && capabilities_s[1] ) begin
        mem_rd_total_words_r <= adapted_size_at_descriptor_s[63:2];

        if(adapted_size_at_descriptor_s[C_LOG2_MAX_READ_REQUEST-1:0] > 0) begin // Get the modulus 2**(log2_max_words_tlp_s)
          mem_rd_total_tlp_r      <= (adapted_size_at_descriptor_s>>(log2_max_words_read_request_s+2))  + 1; // Express size at descriptor as 32 bit word.
          mem_rd_last_tlp_words_r <= ((adapted_size_at_descriptor_s&{C_LOG2_MAX_READ_REQUEST{1'b1}}) >> 2) ;
        end else begin
          mem_rd_total_tlp_r      <= adapted_size_at_descriptor_s>>(log2_max_words_read_request_s+2);
          mem_rd_last_tlp_words_r <= max_words_tlp_s;
        end
      //end else if(ENGINE_VALID &&  (ENGINE_VALID  !end_of_operation_r) begin
      //  mem_rd_total_tlp_r <= 32'b0;
      end else if(ENGINE_VALID && (end_of_operation_r||end_of_operation)) begin
        mem_rd_total_tlp_r <= 32'b0;
      end else begin
        mem_rd_total_tlp_r      <= mem_rd_total_tlp_r;
        mem_rd_total_words_r    <= mem_rd_total_words_r;
        mem_rd_last_tlp_words_r <= mem_rd_last_tlp_words_r;
      end
    end
  end



  ////////
  // · Infer the number of words in the current TLP
  wire        size_change_s            ;
  reg         size_change_r            ;
  reg  [63:0] size_at_descriptor_pipe_r;
  assign size_change_s = size_at_descriptor_pipe_r!=adapted_size_at_descriptor_s;
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      size_at_descriptor_pipe_r <= 64'b0;
      size_change_r             <= 1'b0;
    end else begin
      size_at_descriptor_pipe_r <= adapted_size_at_descriptor_s;
      size_change_r             <= !one_word_at_buffer_s ? size_change_s|size_change_r : size_change_s;
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      mem_wr_remaining_words_r <= 64'h0;
      mem_wr_next_remainder_r  <= 64'h0;
    end else begin
      case(wr_state)
        IDLE : begin
          mem_wr_remaining_words_r <= mem_wr_middle_tlp_words_r;
          mem_wr_next_remainder_r  <= mem_wr_middle_tlp_words_r;
        end
        INIT_WRITE : begin
          if( M_AXIS_RQ_TREADY && one_word_at_buffer_s ) begin
            if(last_word_at_tlp_s) begin
              mem_wr_remaining_words_r <= mem_wr_middle_tlp_words_r;
              mem_wr_next_remainder_r  <= mem_wr_middle_tlp_words_r;
            end else begin
              mem_wr_remaining_words_r <= mem_wr_remaining_words_r - 4;
              mem_wr_next_remainder_r  <= mem_wr_next_remainder_r - 4;
            end
          end
        end
        WRITE : begin
          if(M_AXIS_RQ_TREADY) begin
            if((one_word_at_buffer_s && last_word_at_tlp_s) || (two_words_at_buffer_s && last_two_words_at_tlp_s)) begin
              if(mem_wr_current_tlp_r == mem_wr_total_tlp_r - 1) begin
                mem_wr_remaining_words_r <= mem_wr_last_tlp_words_r;
                mem_wr_next_remainder_r  <= mem_wr_last_tlp_words_r;
              end else begin
                mem_wr_remaining_words_r <= max_words_tlp_s;
                mem_wr_next_remainder_r  <= max_words_tlp_s;
              end
            end else if( two_words_at_buffer_s ) begin
              mem_wr_remaining_words_r <= mem_wr_remaining_words_r - 8;
              mem_wr_next_remainder_r  <= mem_wr_next_remainder_r - 8;
            end
          end
        end
      endcase
    end
  end


  always @(negedge RST_N or posedge CLK) begin
    if (!RST_N) begin
      mem_rd_middle_tlp_words_r <= 64'h0;
    end else begin
      mem_rd_middle_tlp_words_r <= adapted_size_at_descriptor_s[63:2] <= max_words_read_request_s ? adapted_size_at_descriptor_s[63:2] : max_words_read_request_s;
    end
  end
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      mem_rd_remaining_words_r <= 64'h0;
    end else begin
      case(wr_state)
        IDLE : begin
          mem_rd_remaining_words_r <= mem_rd_middle_tlp_words_r;
        end
        INIT_READ : begin
          if(M_AXIS_RQ_TREADY) begin
            if(mem_rd_current_tlp_r >= mem_rd_total_tlp_r-1) begin
              mem_rd_remaining_words_r <= mem_rd_last_tlp_words_r;
            end else begin
              mem_rd_remaining_words_r <= mem_rd_middle_tlp_words_r;
            end
          end
        end
      endcase
    end
  end



  /////////
  // Update the current TLP and memory offset
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      mem_wr_addr_pointed_by_descriptor_r <= 64'b0;
      mem_wr_current_tlp_r                <= 32'h1;
    end else begin
      case(wr_state)
        IDLE : begin
          if (M_AXIS_RQ_TREADY) begin
            mem_wr_current_tlp_r                <= 32'h1;
            mem_wr_addr_pointed_by_descriptor_r <= ADDR_AT_DESCRIPTOR;
          end
        end
        INIT_WRITE : begin
          if(M_AXIS_RQ_TREADY && one_word_at_buffer_s && last_word_at_tlp_s) begin
            mem_wr_current_tlp_r                <= mem_wr_current_tlp_r+1;
            mem_wr_addr_pointed_by_descriptor_r <= ADDR_AT_DESCRIPTOR + (mem_wr_current_tlp_r<<(log2_max_words_tlp_s+2));
          end
        end
        WRITE : begin
          if(M_AXIS_RQ_TREADY) begin
            if((two_words_at_buffer_s && last_two_words_at_tlp_s) || (one_word_at_buffer_s && last_word_at_tlp_s)) begin
              mem_wr_current_tlp_r                <= mem_wr_current_tlp_r+1;
              mem_wr_addr_pointed_by_descriptor_r <= ADDR_AT_DESCRIPTOR + (mem_wr_current_tlp_r<<(log2_max_words_tlp_s+2));
            end
          end
        end
        default : begin
          mem_wr_addr_pointed_by_descriptor_r <= mem_wr_addr_pointed_by_descriptor_r;
          mem_wr_current_tlp_r                <= mem_wr_current_tlp_r;
        end
      endcase
    end
  end
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      mem_rd_addr_pointed_by_descriptor_r <= 64'b0;
      mem_rd_current_tlp_r                <= 32'h1;
    end else begin
      case(wr_state)
        IDLE : begin
          if (M_AXIS_RQ_TREADY) begin
            mem_rd_current_tlp_r                <= 32'h1;
            mem_rd_addr_pointed_by_descriptor_r <= ADDR_AT_DESCRIPTOR;
          end
        end
        INIT_READ : begin
          if((current_tags_r & window_size_mask_r)!=window_size_mask_r && M_AXIS_RQ_TREADY) begin
            mem_rd_current_tlp_r                <= mem_rd_current_tlp_r+1;
            mem_rd_addr_pointed_by_descriptor_r <= ADDR_AT_DESCRIPTOR + (mem_rd_current_tlp_r<<(log2_max_words_read_request_s+2));
          end
        end

        default : begin
          mem_rd_addr_pointed_by_descriptor_r <= mem_rd_addr_pointed_by_descriptor_r;
          mem_rd_current_tlp_r                <= mem_rd_current_tlp_r;
        end
      endcase
    end
  end
  assign c2s_rq_tag_s = mem_wr_current_tlp_r-1;

  assign WORD_COUNT = mem_wr_total_words_r;




  ////////
  // Update the states of the FSMs
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      wr_state_pipe_r <= IDLE;
    end else begin
      wr_state_pipe_r <= wr_state;
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      state <= IDLE;
    end else begin
      case(state)
        IDLE : begin
          if(M_AXIS_RQ_TREADY) begin //Assure previous packets have been sent
            if( ENGINE_VALID && !end_of_operation_r  && !end_of_operation  && (mem_wr_current_tlp_r <= mem_wr_total_tlp_r || mem_rd_current_tlp_r <= mem_rd_total_tlp_r )) begin
              state <= WAIT_WR_OP;
            end else begin
              state <= IDLE;
            end
          end else begin
            state <= IDLE;
          end
        end
        WAIT_WR_OP : begin
          if(end_of_operation) begin
            state <= IDLE;
          end else begin
            state <= WAIT_WR_OP;
          end
        end
        default : begin
          state <= IDLE;
        end
      endcase
    end
  end

  ////////
  // FSM
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      wr_state <= IDLE;
    end else begin
      case(wr_state)
        IDLE : begin // TODO: Check both possibilities (read/write)
          if(M_AXIS_RQ_TREADY && capabilities_s[0] && ENGINE_VALID && !end_of_operation_r  && !end_of_operation  && (mem_wr_current_tlp_r <= mem_wr_total_tlp_r)) begin  // C2S engine
            wr_state <= INIT_WRITE;
          end else if(M_AXIS_RQ_TREADY && capabilities_s[1] && ENGINE_VALID && !end_of_operation_r && !end_of_operation && (mem_rd_current_tlp_r <= mem_rd_total_tlp_r)) begin
            wr_state <= INIT_READ;
          end
        end
        INIT_WRITE : begin     // Write to the Completer the TLP header.
          if(M_AXIS_RQ_TREADY) begin
            if( !one_word_at_buffer_s ) begin // There is no data.
              wr_state <= INIT_WRITE;
            end else if(last_word_at_tlp_s) begin // We complete the transfer in one cycle
              if(mem_wr_total_tlp_r <= mem_wr_current_tlp_r) begin
                wr_state <= capabilities_s[1] ? INIT_READ : IDLE;
              end else begin
                wr_state = INIT_WRITE;
              end
            end else begin      //Else we have to send more packets
              wr_state <= WRITE;
            end
          end else begin
            wr_state <= INIT_WRITE;
          end
        end
        WRITE : begin          // Write to the Completer the rest of the information.
          if(M_AXIS_RQ_TREADY) begin
            if((last_word_at_tlp_s && one_word_at_buffer_s) || (last_two_words_at_tlp_s && two_words_at_buffer_s)) begin
              if(mem_wr_total_tlp_r <= mem_wr_current_tlp_r) begin
                wr_state <= capabilities_s[1] ? INIT_READ : IDLE;
              end else begin
                wr_state <= INIT_WRITE;
              end
            end else begin
              wr_state <= WRITE;
            end
          end else begin
            wr_state <= WRITE;
          end
        end
        INIT_READ : begin
          if(M_AXIS_RQ_TREADY && mem_rd_total_tlp_r <= mem_rd_current_tlp_r && (current_tags_r & window_size_mask_r)!=window_size_mask_r) begin
            wr_state <= WAIT_READ;
          end else begin
            wr_state <= INIT_READ;
          end
        end
        WAIT_READ : begin
          if(end_of_operation) begin
            wr_state <= IDLE;
          end else begin
            wr_state <= WAIT_READ;
          end
        end
        default : begin
          wr_state <= IDLE;
        end
      endcase
    end
  end


  ////////
  // Update the current tag (memory read request)

  function [7:0] firstFree(input [C_WINDOW_SIZE-1:0] oh);
    integer k;
    begin
      firstFree = 0;
      for (k=C_WINDOW_SIZE-1; k>=0; k=k-1) begin
        if (oh[k]==0) firstFree = k;
      end
    end
  endfunction

  function [C_WINDOW_SIZE-1:0] firstFree_oh(input [C_WINDOW_SIZE-1:0] oh);
    integer k;
    begin
      firstFree_oh = 0;
      for (k=C_WINDOW_SIZE-1; k>=0; k=k-1) begin
        if (oh[k]==0) firstFree_oh = (1<<k);
      end
    end
  endfunction

  generate for  (j=0; j<C_WINDOW_SIZE; j=j+1) begin
      always @(negedge RST_N or posedge CLK) begin
        if(!RST_N) begin
          current_tags_r[j] <= 0;
          size_tags_r[j] <= 0;
        end else begin
          if(wr_state == INIT_READ && M_AXIS_RQ_TREADY &&  j<CURRENT_WINDOW_SIZE[7:0] && j==firstFree(current_tags_r)) begin
            current_tags_r[j] <= !COMPLETED_TAGS[j];
            size_tags_r[j] <= current_tags_r[j] ?  size_tags_r[j] : mem_rd_remaining_words_r[10:0]; //How many bytes are we waiting?
          end else begin
            current_tags_r[j] <= current_tags_r[j] & !COMPLETED_TAGS[j];
          end
        end
      end
    end
  endgenerate


  assign BUSY_TAGS    = current_tags_r;
  assign s2c_rq_tag_s = firstFree(current_tags_r);
  ////////
  // Split the data
  dma_rq_d2h_splitter #(
    .C_MODULE_IN_USE   (0                 ), // Ignore it
    .C_BUS_DATA_WIDTH  (C_BUS_DATA_WIDTH  ),
    .C_BUS_KEEP_WIDTH  (C_AXI_KEEP_WIDTH  ),
    .C_LOG2_MAX_PAYLOAD(C_LOG2_MAX_PAYLOAD)
  ) dma_rq_d2h_splitter_i (
    .CLK                      (CLK                         ),
    .RST_N                    (RST_N                       ),
    .C2S_FIFO_TREADY          (C2S_FIFO_TREADY             ),
    .C2S_FIFO_TDATA           (C2S_FIFO_TDATA              ),
    .C2S_FIFO_TLAST           (C2S_FIFO_TLAST              ),
    .C2S_FIFO_TVALID          (C2S_FIFO_TVALID             ),
    .C2S_FIFO_TKEEP           (C2S_FIFO_TKEEP              ),
    .C2S_PROC_TREADY          (c2s_proc_tready_s           ),
    .C2S_PROC_TDATA           (c2s_proc_tdata_s            ),
    .C2S_PROC_TLAST           (c2s_proc_tlast_s            ),
    .C2S_PROC_TVALID          (c2s_proc_tvalid_s           ),
    .C2S_PROC_TKEEP           (c2s_proc_tkeep_s            ),
    .ENGINE_STATE             (state                       ),
    .C2S_STATE                (wr_state                    ),
    .CURRENT_DESCRIPTOR_SIZE  (adapted_size_at_descriptor_s),
    .DESCRIPTOR_MAX_TIMEOUT   (DESCRIPTOR_MAX_TIMEOUT      ),
    .HW_REQUEST_TRANSFERENCE  (HW_REQUEST_TRANSFERENCE     ),
    .HW_NEW_SIZE_AT_DESCRIPTOR(HW_NEW_SIZE_AT_DESCRIPTOR   )
  );


  reg update_latency_r;
  reg [63:0]  current_latency_r;
  reg [63:0]  time_comp_r;
  reg [63:0]  time_req_r;
  reg [63:0]  bytes_comp_r;
  reg [63:0]  bytes_req_r;

  reg stop_latency;
  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      update_latency_r <= 1'b0;
      stop_latency <= 1'b1;
    end else begin
      update_latency_r <= 1'b0;
      if( wr_state == INIT_WRITE && capabilities_s[0] && M_AXIS_RQ_TREADY ) begin
        stop_latency <= 1'b0;
      end else if ( wr_state == INIT_READ && capabilities_s[1] && M_AXIS_RQ_TREADY ) begin
        stop_latency <= 1'b0;
      end else if (end_of_operation) begin //(wr_state == IDLE)
        stop_latency <= 1'b1;
        update_latency_r <= 1'b1;
      end
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      current_latency_r <= 64'b0;
    end else begin
      if(stop_latency) begin
        current_latency_r <= 64'b0;
      end else begin
        current_latency_r <= current_latency_r+1;
      end
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      time_req_r <= 64'b0;
    end else begin
      if(stop_latency) begin
        time_req_r <= 64'b0;
      end else if(wr_state != IDLE && M_AXIS_RQ_TVALID && M_AXIS_RQ_TREADY) begin
        time_req_r <= time_req_r+1;
      end else if(wr_state != WAIT_READ && time_req_r) begin
        time_req_r <= time_req_r+1;
      end
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      time_comp_r <= 64'b0;
    end else begin
      if(stop_latency) begin
        time_comp_r <= 64'b0;
      end else if(wr_state!=IDLE && S_AXIS_RC_TVALID && S_AXIS_RC_TREADY ) begin
        time_comp_r <= time_comp_r+1;
      end else if(time_comp_r) begin
        time_comp_r <= time_comp_r+1;
      end
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      bytes_comp_r <= 64'b0;
    end else begin
      if(stop_latency) begin
        bytes_comp_r <= 64'b0;
      end else if(S_AXIS_RC_TVALID && S_AXIS_RC_TREADY) begin
        bytes_comp_r <= bytes_comp_r
          +S_AXIS_RC_TKEEP[0]+S_AXIS_RC_TKEEP[1]+S_AXIS_RC_TKEEP[2]+S_AXIS_RC_TKEEP[3]
          +S_AXIS_RC_TKEEP[4]+S_AXIS_RC_TKEEP[5]+S_AXIS_RC_TKEEP[6]+S_AXIS_RC_TKEEP[7];
      end
    end
  end

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      bytes_req_r <= 64'b0;
    end else begin
      if(stop_latency) begin
        bytes_req_r <= 64'b0;
      end else if(M_AXIS_RQ_TVALID && M_AXIS_RQ_TREADY) begin
        bytes_req_r <= bytes_req_r
          +M_AXIS_RQ_TKEEP[0]+M_AXIS_RQ_TKEEP[1]+M_AXIS_RQ_TKEEP[2]+M_AXIS_RQ_TKEEP[3]
          +M_AXIS_RQ_TKEEP[4]+M_AXIS_RQ_TKEEP[5]+M_AXIS_RQ_TKEEP[6]+M_AXIS_RQ_TKEEP[7];
      end
    end
  end

  assign UPDATE_LATENCY  = update_latency_r;
  assign CURRENT_LATENCY = current_latency_r;
  assign TIME_AT_REQ     = time_req_r;
  assign TIME_AT_COMP    = time_comp_r;
  assign BYTES_AT_REQ    = bytes_req_r;
  assign BYTES_AT_COMP   = bytes_comp_r;

endmodule