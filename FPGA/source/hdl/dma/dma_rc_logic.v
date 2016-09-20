/**
@class dma_rc_logic

@author      Jose Fernando Zazo Rollon (josefernando.zazo@estudiante.uam.es)
@date        06/05/2015

@brief Design containing  the DMA requester completion interface. A completion TLP
must start at byte 0 in the AXI stream interface. Straddle option not supported.

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

module dma_rc_logic #(
  parameter C_BUS_DATA_WIDTH        = 256,
  parameter                                           C_BUS_KEEP_WIDTH = (C_BUS_DATA_WIDTH/32),
  parameter C_WINDOW_SIZE           = 16 ,
  parameter C_LOG2_MAX_PAYLOAD      = 8  , // 2**C_LOG2_MAX_PAYLOAD in bytes
  parameter C_LOG2_MAX_READ_REQUEST = 14   // 2**C_LOG2_MAX_READ_REQUEST in bytes
) (
  input  wire                        CLK                ,
  input  wire                        RST_N              ,
  ////////////
  //  PCIe Interface: 1 AXI-Stream (requester side)
  ////////////
  input  wire [C_BUS_DATA_WIDTH-1:0] S_AXIS_RC_TDATA    ,
  input  wire [                74:0] S_AXIS_RC_TUSER    ,
  input  wire                        S_AXIS_RC_TLAST    ,
  input  wire [C_BUS_KEEP_WIDTH-1:0] S_AXIS_RC_TKEEP    ,
  input  wire                        S_AXIS_RC_TVALID   ,
  output wire [                21:0] S_AXIS_RC_TREADY   ,
  ////////////
  //  s2c fifo interface: 1 AXI-Stream
  ////////////
  output wire                        S2C_FIFO_TVALID    ,
  input  wire                        S2C_FIFO_TREADY    ,
  output wire [C_BUS_DATA_WIDTH-1:0] S2C_FIFO_TDATA     ,
  output wire                        S2C_FIFO_TLAST     ,
  output wire [C_BUS_KEEP_WIDTH-1:0] S2C_FIFO_TKEEP     ,
  ////////////
  //  Descriptor interface: Interface with the necessary data to complete a memory read/write request.
  ////////////
  output wire [                63:0] BYTE_COUNT         ,
  input  wire [                63:0] WORD_COUNT         ,
  input  wire [   C_WINDOW_SIZE-1:0] BUSY_TAGS          ,
  input  wire [C_WINDOW_SIZE*11-1:0] SIZE_TAGS          ,
  input  wire [                63:0] CURRENT_WINDOW_SIZE,
  output wire [   C_WINDOW_SIZE-1:0] COMPLETED_TAGS     ,
  output wire                        END_OF_TAG         ,
  output wire [                 7:0] LAST_TAG           ,
  output wire [                63:0] DEBUG
);


  assign ERROR_TAGS       = 0;
  assign DEBUG            = 0;
  assign S2C_FIFO_TVALID  = 0;
  assign S2C_FIFO_TDATA   = 0;
  assign S2C_FIFO_TLAST   = 0;
  assign S2C_FIFO_TKEEP   = 0;
  assign BYTE_COUNT       = 0;
  assign S_AXIS_RC_TREADY = {22{1'b1}};
  wire [10:0] tlp_dwords_s;

  assign tlp_dwords_s = S_AXIS_RC_TDATA[42:32];

  reg is_rc_sop_r;
  always @(negedge RST_N or posedge CLK) begin
    if (!RST_N) begin
      is_rc_sop_r <= 1'b1;
    end else  begin
      if(S_AXIS_RC_TLAST && S_AXIS_RC_TVALID && S_AXIS_RC_TREADY) begin
        is_rc_sop_r <= 1'b1;  // Select the dout from the dma component
      end else if( S_AXIS_RC_TVALID && S_AXIS_RC_TREADY ) begin
        is_rc_sop_r <= 1'b0;  // Else msix
      end else begin
        is_rc_sop_r <= is_rc_sop_r;
      end
    end
  end
  // Just for debug
  reg [10:0] word_count_r;
  always @(negedge RST_N or posedge CLK) begin
    if (!RST_N) begin
      word_count_r <= 0;
    end else  begin
      if(is_rc_sop_r & S_AXIS_RC_TVALID && S_AXIS_RC_TREADY ) begin
        word_count_r <= word_count_r + tlp_dwords_s;
      end else if (BUSY_TAGS==0) begin
        word_count_r <= 0;
      end
    end
  end
  ///////

  wire [             10:0] size_tags_s            [C_WINDOW_SIZE-1:0]; // Expected number of words
  reg  [             10:0] word_count_tag_r       [C_WINDOW_SIZE-1:0]; // Completed words
  reg  [             10:0] difference_r           [C_WINDOW_SIZE-1:0];
  wire [              7:0] tlp_tag_s                                 ;
  reg  [C_WINDOW_SIZE-1:0] is_tag_ready_r                            ;
  reg  [C_WINDOW_SIZE-1:0] is_tag_count_exceeded_r                   ;

  assign tlp_tag_s         = S_AXIS_RC_TDATA[71:64];
  assign s2c_fifo_tready_s = S2C_FIFO_TREADY;


  // Strip the bus and divide it as an array (code more intelligible)
  reg [C_WINDOW_SIZE-1:0] completed_tags_r;
  reg                     end_of_tag_r    ;
  reg [              7:0] tlp_tag_r       ;

  always @(negedge RST_N or posedge CLK) begin
    if(!RST_N) begin
      end_of_tag_r <= 1'b0;
      tlp_tag_r <= 0;
    end else begin
      end_of_tag_r <= (S_AXIS_RC_TVALID && S_AXIS_RC_TREADY && S_AXIS_RC_TLAST );
      if(is_rc_sop_r) begin
        tlp_tag_r <= tlp_tag_s;
      end
    end
  end   


  assign END_OF_TAG = end_of_tag_r;
  assign LAST_TAG   = tlp_tag_r;
  genvar j;
  for(j=0; j<C_WINDOW_SIZE;j=j+1) begin
      assign size_tags_s[j]    = SIZE_TAGS[11*(j+1)-1:11*j];

      assign COMPLETED_TAGS[j] = completed_tags_r[j];
      always @(negedge RST_N or posedge CLK) begin
        if(!RST_N) begin
          completed_tags_r[j] <= 1'b0;
        end else begin
          completed_tags_r[j] <= BUSY_TAGS[j] && (S_AXIS_RC_TVALID && S_AXIS_RC_TREADY && S_AXIS_RC_TLAST )
              && ((is_tag_count_exceeded_r[j]) // We exceed the requested size. Take into account completions in one pulse
                || (j==tlp_tag_s && tlp_dwords_s<=5 && tlp_dwords_s>=difference_r[j]));
        end
      end      
  end

  generate for (j=0;j<C_WINDOW_SIZE;j=j+1) begin

      always @(negedge RST_N or posedge CLK) begin
        if (!RST_N) begin
          word_count_tag_r[j] <= 0;
        end else  begin
          if(is_rc_sop_r & S_AXIS_RC_TVALID && S_AXIS_RC_TREADY && j==tlp_tag_s ) begin
           // if (COMPLETED_TAGS[j]) begin
            if(S_AXIS_RC_TLAST && tlp_dwords_s<=5 && tlp_dwords_s>=difference_r[j]) begin
              word_count_tag_r[j] <= 0;
            end else begin
              word_count_tag_r[j] <= word_count_tag_r[j] + tlp_dwords_s;
            end
          end else begin
            if (COMPLETED_TAGS[j])
              word_count_tag_r[j] <= 0;
          end
        end
      end


      always @(negedge RST_N or posedge CLK) begin
        if (!RST_N) begin
          difference_r[j] <= 0;
        end else  begin
          if(is_rc_sop_r & S_AXIS_RC_TVALID && S_AXIS_RC_TREADY && j==tlp_tag_s ) begin
            difference_r[j] <= size_tags_s[j] - word_count_tag_r[j] - tlp_dwords_s;
          end else begin
            difference_r[j] <=  size_tags_s[j] - word_count_tag_r[j];
          end
        end
      end


      always @(negedge RST_N or posedge CLK) begin
        if (!RST_N) begin
          is_tag_count_exceeded_r[j] <= 1'b0;
        end else  begin

          if(is_rc_sop_r & S_AXIS_RC_TVALID && S_AXIS_RC_TREADY && j==tlp_tag_s && BUSY_TAGS[j] ) begin
            if(!(S_AXIS_RC_TLAST && tlp_dwords_s<=5 && tlp_dwords_s>=difference_r[j])) // Do ee end the operation in one pulse. Do not assert the signal in that case
              is_tag_count_exceeded_r[j] <=  (size_tags_s[j] - word_count_tag_r[j]) <= tlp_dwords_s;
          end else begin
            is_tag_count_exceeded_r[j]  <= (word_count_tag_r[j] >= size_tags_s[j]);
          end

        end
      end
    end
  endgenerate

  //

endmodule