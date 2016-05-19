//
// Copyright (c) 2015
// All rights reserved.
//
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
//


`timescale 1ns / 1ps
`default_nettype none



module pcie_completer_to_bram
#(
 // AXI Stream Parameters
  parameter BAR                      = 0          
)(
  input  wire                 user_clk,
  input  wire                 reset_n,

 //AXI-S Completer Request Interface
  input  wire  [255:0]        m_axis_cq_tdata,
  input  wire                 m_axis_cq_tlast,
  input  wire                 m_axis_cq_tvalid,
  input  wire  [84:0]         m_axis_cq_tuser,
  input  wire  [7:0]         m_axis_cq_tkeep,
  output reg                  m_axis_cq_tready,
  
  // AXI-S Completer Competion Interface 
  output reg   [255:0]        s_axis_cc_tdata,
  output reg   [7:0]         s_axis_cc_tkeep,
  output reg                  s_axis_cc_tlast,
  output reg                  s_axis_cc_tvalid,
  output reg   [32:0]         s_axis_cc_tuser,
  input  wire                 s_axis_cc_tready,
  
  output reg                  en,
  output reg   [23:0]         addr,
  input wire   [63:0]         dout,
  output reg   [63:0]         din,
  output reg   [7:0]          we,
  input wire                  ack
    
);

  wire [1:0]  cq_at;  
  wire [61:0] cq_addr;
  wire [10:0] cq_dword_cnt;
  wire [3:0]  cq_type; 
  wire [15:0] cq_reqr_id;
  wire [7:0]  cq_tag;
  wire [2:0]  cq_bar_id;
  wire [2:0]  cq_tc;
  wire [2:0]  cq_attr;
  wire [63:0] cq_data;
  wire [3:0]  cq_first_be;
  wire [3:0]  cq_last_be;
  wire        cq_sop;
  wire        cq_discontinue;
  
  reg  [1:0]  req_at;  
  reg  [61:0] req_addr;
  reg  [10:0] req_dword_cnt;
  reg  [3:0]  req_type; 
  reg  [15:0] req_reqr_id;
  reg  [7:0]  req_tag;
  reg  [2:0]  req_bar_id;
  reg  [2:0]  req_tc;
  reg  [2:0]  req_attr;
  reg  [63:0] req_data;
  reg  [3:0]  req_first_be;
  reg  [3:0]  req_last_be;
  
  reg  [6:0]  cpl_lower_addr;
  reg  [12:0] cpl_byte_cnt;
  reg  [63:0] cpl_data;  
  
  wire cq_valid_bar;
  wire cq_valid_dword_cnt;
   

  
  enum {S_RESET, S_WAIT_FOR_REQ, S_STORE_WR_REQ, S_STORE_RD_REQ, S_WAIT_FOR_RD_CPL, S_SEND_RD_CPL, S_SEND_UNSUPPORTED_REQ} state;
    
  enum {NO_REQ, VALID_RD_REQ, VALID_WR_REQ, UNSUPPORTED_REQ} decoded_req; 
    
    
  `define C_MEM_RD_REQ 4'b0000
  `define C_MEM_WR_REQ 4'b0001
  
  assign cq_at = m_axis_cq_tdata[1:0];  
  assign cq_addr = m_axis_cq_tdata[63:2];
  assign cq_dword_cnt = m_axis_cq_tdata[74:64];
  assign cq_type = m_axis_cq_tdata[78:75];
  assign cq_reqr_id = m_axis_cq_tdata[95:80];
  assign cq_tag = m_axis_cq_tdata[103:96];
  assign cq_bar_id = m_axis_cq_tdata[114:112];
  assign cq_tc = m_axis_cq_tdata[123:121];
  assign cq_attr = m_axis_cq_tdata[126:124];
  assign cq_data = m_axis_cq_tdata[191:128];
  assign cq_first_be = m_axis_cq_tuser[3:0];
  assign cq_last_be = m_axis_cq_tuser[7:4];
  assign cq_sop = m_axis_cq_tuser[40];
  assign cq_discontinue = m_axis_cq_tuser[41];

  assign cq_valid_bar = (cq_bar_id==BAR) ? 1 : 0;
  assign cq_valid_dword_cnt = ((cq_dword_cnt==1) || (cq_dword_cnt==2)) ? 1 : 0; 
  
  // Decode valid read and write requests
  always_comb begin
    if (cq_sop && !cq_discontinue && m_axis_cq_tvalid) begin
      if ((cq_type==`C_MEM_RD_REQ) && cq_valid_bar) begin
        if (cq_valid_dword_cnt) begin
          decoded_req = VALID_RD_REQ;
        end else begin
          decoded_req = UNSUPPORTED_REQ;
        end
      end else if ((cq_type==`C_MEM_WR_REQ) && cq_valid_bar) begin
        if (cq_valid_dword_cnt) begin
          decoded_req = VALID_WR_REQ;
        end else begin
          decoded_req = UNSUPPORTED_REQ;
        end
      end else begin
        decoded_req = NO_REQ;
      end
    end else begin
      decoded_req = NO_REQ;
    end
  end

  // 
  always_ff @(posedge user_clk, negedge reset_n) begin
    if (!reset_n) begin
      state <= S_RESET;
    end else begin
      case (state)      
        // 
        S_RESET: begin
          state <= S_WAIT_FOR_REQ;
        end
        //
        S_WAIT_FOR_REQ: begin
          case (decoded_req) 
            NO_REQ: state <= S_WAIT_FOR_REQ;
            VALID_RD_REQ: state <= S_STORE_RD_REQ;
            VALID_WR_REQ: state <= S_STORE_WR_REQ;
            UNSUPPORTED_REQ: state <= S_SEND_UNSUPPORTED_REQ;
          endcase
        end
        // 
        S_STORE_WR_REQ: begin
          state <= S_WAIT_FOR_REQ;
        end  
        // 
        S_STORE_RD_REQ: begin
          state <= S_WAIT_FOR_RD_CPL;
        end
        //
        S_WAIT_FOR_RD_CPL: begin
          if (ack) begin
            state <= S_SEND_RD_CPL;
          end
        end
        //
        S_SEND_RD_CPL: begin
          if (s_axis_cc_tready) begin
            state <= S_WAIT_FOR_REQ;
          end
        end
        //
        S_SEND_UNSUPPORTED_REQ: begin
          state <= S_WAIT_FOR_REQ;
        end
      endcase
    end
  end

  assign m_axis_cq_tready = (state == S_WAIT_FOR_REQ) ? 1'b1 : 1'b0;
  
  always_ff @(posedge user_clk) begin
    if ((state==S_WAIT_FOR_REQ) && (decoded_req!=NO_REQ)) begin
      req_at = cq_at;
      req_addr = cq_addr;
      req_dword_cnt = cq_dword_cnt;
      req_type = cq_type; 
      req_reqr_id = cq_reqr_id;
      req_tag = cq_tag;
      req_bar_id = cq_bar_id;
      req_tc = cq_tc;
      req_attr = cq_attr;
      req_first_be = cq_first_be;
      req_last_be = cq_last_be;
      req_data = cq_data;
    end
  end
    

  //////////////////////
  // MEMORY INTERFACE //
  //////////////////////

  always_comb begin
    // enable and address
    if ((state == S_STORE_RD_REQ) || (state == S_STORE_WR_REQ)) begin
      addr = req_addr[24:1];
      en = 1;
    end else begin
      addr = req_addr[24:1];
      en = 0;
    end
    // write data and byte enables
    if (state == S_STORE_WR_REQ) begin
      if (req_dword_cnt == 1) begin
        if (req_addr[0]) begin
          din = {req_data[31:0],32'b0};
          we = {req_first_be,4'b0};
        end else begin
          din = {32'b0,req_data[31:0]};
          we = {4'b0,req_first_be};
        end
      end else begin
        din = req_data;
        we = {req_last_be, req_first_be};
      end
    end else begin
      din = 64'b0;
      we = 8'b0;
    end
  end
      
  ////////////////
  // COMPLETION //
  ////////////////
  
  always_ff @(posedge user_clk) begin
    if (state == S_WAIT_FOR_RD_CPL) begin
      if (req_dword_cnt == 1) begin
        // Completion Data
        if (req_addr[0]) begin
          cpl_data = {32'b0, dout[63:32]};
        end else begin
          cpl_data = {32'b0, dout[31:0]};
        end
        // Completion Byte Count and Lower Address 
        casex (req_first_be)
          4'b1xx1: begin
            cpl_byte_cnt = 4;
            cpl_lower_addr = {req_addr, 2'b00};
          end
          4'b01x1: begin
            cpl_byte_cnt = 3;
            cpl_lower_addr = {req_addr, 2'b00};
          end
          4'b1x10: begin
            cpl_byte_cnt = 3;
            cpl_lower_addr = {req_addr, 2'b01};
          end
          4'b0011: begin
            cpl_byte_cnt = 2;
            cpl_lower_addr = {req_addr, 2'b00};
          end
          4'b0110: begin
            cpl_byte_cnt = 2;
            cpl_lower_addr = {req_addr, 2'b01};
          end
          4'b1100: begin
            cpl_byte_cnt = 2;
            cpl_lower_addr = {req_addr, 2'b10};
          end
          4'b0001: begin
            cpl_byte_cnt = 1;
            cpl_lower_addr = {req_addr, 2'b00};
          end
          4'b0010: begin
            cpl_byte_cnt = 1;
            cpl_lower_addr = {req_addr, 2'b01};
          end
          4'b0100: begin
            cpl_byte_cnt = 1;
            cpl_lower_addr = {req_addr, 2'b10};
          end
          4'b1000: begin
            cpl_byte_cnt = 1;
            cpl_lower_addr = {req_addr, 2'b11};
          end
        endcase
      end else begin
        // Completion Data
        cpl_data = dout;
        // Completion Byte Count and Lower Address         
        casex ({req_last_be,req_first_be})
          8'b1xxxxxx1: begin
            cpl_byte_cnt = 8;
            cpl_lower_addr = {req_addr, 2'b00};
          end
          8'b01xxxxx1: begin
            cpl_byte_cnt = 7;
            cpl_lower_addr = {req_addr, 2'b00};
          end
          8'b001xxxx1: begin
            cpl_byte_cnt = 6;
            cpl_lower_addr = {req_addr, 2'b00};
          end
          8'b0001xxx1: begin
            cpl_byte_cnt = 5;
            cpl_lower_addr = {req_addr, 2'b00};
          end
          8'b1xxxxx10: begin
            cpl_byte_cnt = 7;
            cpl_lower_addr = {req_addr, 2'b01};
          end
          8'b01xxxx10: begin
            cpl_byte_cnt = 6;
            cpl_lower_addr = {req_addr, 2'b01};
          end
          8'b001xxx10: begin
            cpl_byte_cnt = 5;
            cpl_lower_addr = {req_addr, 2'b01};
          end
          8'b0001xx10: begin
            cpl_byte_cnt = 4;
            cpl_lower_addr = {req_addr, 2'b01};
          end
          8'b1xxxx100: begin
            cpl_byte_cnt = 6;
            cpl_lower_addr = {req_addr, 2'b10};
          end
          8'b01xxx100: begin
            cpl_byte_cnt = 5;
            cpl_lower_addr = {req_addr, 2'b10};
          end
          8'b001xx100: begin
            cpl_byte_cnt = 4;
            cpl_lower_addr = {req_addr, 2'b10};
          end
          8'b0001x100: begin
            cpl_byte_cnt = 3;
            cpl_lower_addr = {req_addr, 2'b10};
          end
          8'b1xxx1000: begin
            cpl_byte_cnt = 5;
            cpl_lower_addr = {req_addr, 2'b11};
          end
          8'b01xx1000: begin
            cpl_byte_cnt = 4;
            cpl_lower_addr = {req_addr, 2'b11};
          end
          8'b001x1000: begin
            cpl_byte_cnt = 3;
            cpl_lower_addr = {req_addr, 2'b11};
          end
          8'b00011000: begin
            cpl_byte_cnt = 2;
            cpl_lower_addr = {req_addr, 2'b11};
          end
        endcase
      end
    end
  end

  always_comb begin
    if (state == S_SEND_RD_CPL) begin
      // tdata
      s_axis_cc_tdata[6:0] = cpl_lower_addr;    // Lower Address  
      s_axis_cc_tdata[7] = 1'b0;
      s_axis_cc_tdata[9:8] = req_at;            // Address Type 
      s_axis_cc_tdata[15:10] = 6'b0;            // Reserved
      s_axis_cc_tdata[28:16] = cpl_byte_cnt;    // Byte Count
      s_axis_cc_tdata[29] = 1'b0;               // Locked Read Completion
      s_axis_cc_tdata[31:30] = 2'b0;            // Reserved
      s_axis_cc_tdata[42:32] = req_dword_cnt;   // Dword Count
      s_axis_cc_tdata[45:43] = 3'b0;            // Completion Status
      s_axis_cc_tdata[46] = 1'b0;               // Poisoned Completion
      s_axis_cc_tdata[47] = 1'b0;               // Reserved
      s_axis_cc_tdata[63:48] = req_reqr_id;     // Requester ID
      s_axis_cc_tdata[71:64] = req_tag;         // Tag
      s_axis_cc_tdata[87:72] = 16'b0;           // Completer ID
      s_axis_cc_tdata[88] = 1'b0;               // Completer ID Enable
      s_axis_cc_tdata[91:89] =req_tc;           // Transaction Class
      s_axis_cc_tdata[94:92] =req_attr;         // Attributes
      s_axis_cc_tdata[95] = 1'b0;               // Force ECRC
      s_axis_cc_tdata[159:96] = cpl_data;
      s_axis_cc_tdata[255:160] = 96'b0;
      // tuser
      s_axis_cc_tuser[0] = 1'b0;                // Discontinue
      s_axis_cc_tuser[32:1] = 32'b0;            // Reserved
      // tkeep
      if (req_dword_cnt==1) s_axis_cc_tkeep = 8'b00001111;
      else s_axis_cc_tkeep = 8'b00011111;
      // tlast
      s_axis_cc_tlast = 1'b1;
      // tvalid
      s_axis_cc_tvalid = 1'b1;
    end else begin
      s_axis_cc_tdata[255:0] = 256'b0;
      s_axis_cc_tuser[32:0] = 33'b0;
      s_axis_cc_tkeep = 8'b00000000;
      s_axis_cc_tlast = 1'b0;
      s_axis_cc_tvalid = 1'b0;
    end
  end
  
endmodule
