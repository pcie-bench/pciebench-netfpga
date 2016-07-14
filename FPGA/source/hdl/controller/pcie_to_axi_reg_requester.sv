// Copyright (c) 2016
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




`timescale 1ns / 1ps
`default_nettype none



module pcie_to_axi_reg_requester #(
  // AXI Stream Parameters
  parameter C_DATA_WIDTH            = 256         ,
  parameter KEEP_WIDTH              = C_DATA_WIDTH /32,
  // AXI4-Lite Parameters
  parameter C_M_AXI_LITE_ADDR_WIDTH = 9           ,
  parameter C_M_AXI_LITE_DATA_WIDTH = 32          ,
  parameter C_FAMILY                         = "virtex7"
) (
  input  wire         user_clk          ,
  input  wire         reset_n           ,
  //AXI-S Completer Request Interface
  input  wire [255:0] m_axis_cq_tdata   ,
  input  wire         m_axis_cq_tlast   ,
  input  wire         m_axis_cq_tvalid  ,
  input  wire [ 84:0] m_axis_cq_tuser   ,
  input  wire [  7:0] m_axis_cq_tkeep   ,
  output reg          m_axis_cq_tready  ,
  // AXI-S Completer Competion Interface
  output reg  [255:0] s_axis_cc_tdata   ,
  output reg  [  7:0] s_axis_cc_tkeep   ,
  output reg          s_axis_cc_tlast   ,
  output reg          s_axis_cc_tvalid  ,
  output reg  [ 32:0] s_axis_cc_tuser   ,
  input  wire         s_axis_cc_tready  ,
  // AXI-LITE MASTER interface
  // clk && rst
  input  wire         m_axi_lite_aclk   ,
  input  wire         m_axi_lite_aresetn,
  // Master detected error
  output reg          md_error          ,
  // AXI4 Read Address Channel
  input  wire         m_axi_lite_arready,
  output reg          m_axi_lite_arvalid,
  output reg  [ 31:0] m_axi_lite_araddr ,
  output reg  [  2:0] m_axi_lite_arprot ,
  // AXI4 Read Data Channel
  output reg          m_axi_lite_rready ,
  input  wire         m_axi_lite_rvalid ,
  input  wire [ 31:0] m_axi_lite_rdata  ,
  input  wire [  1:0] m_axi_lite_rresp  ,
  // AXI4 Write Address Channel
  input  wire         m_axi_lite_awready,
  output reg          m_axi_lite_awvalid,
  output reg  [ 31:0] m_axi_lite_awaddr ,
  output reg  [  2:0] m_axi_lite_awprot ,
  // AXI4 Write Data Channel
  input  wire         m_axi_lite_wready ,
  output reg          m_axi_lite_wvalid ,
  output reg  [ 31:0] m_axi_lite_wdata  ,
  output reg  [  3:0] m_axi_lite_wstrb  ,
  // AXI4 Write Response Channel
  output reg          m_axi_lite_bready ,
  input  wire         m_axi_lite_bvalid ,
  input  wire [  1:0] m_axi_lite_bresp
);

  wire w_fifo_tready;
  reg  w_fifo_tvalid;

  wire wa_fifo_tready;
  reg  wa_fifo_tvalid;

  wire ra_fifo_tready;
  reg  ra_fifo_tvalid;

  wire        r_fifo_m_tvalid;
  reg         r_fifo_m_tready;
  wire [31:0] r_fifo_m_tdata ;
  wire [11:0] r_fifo_m_tuser ;


  reg         d_fifo_s_tvalid;
  wire        d_fifo_s_tready;
  reg  [31:0] d_fifo_s_tdata ;
  reg  [11:0] d_fifo_s_tuser ;

  wire        d_fifo_m_tvalid;
  reg         d_fifo_m_tready;
  wire [31:0] d_fifo_m_tdata ;
  wire [11:0] d_fifo_m_tuser ;

  wire [ 1:0] cq_d_at       ;
  wire [61:0] cq_d_addr     ;
  wire [10:0] cq_d_dword_cnt;
  wire [ 3:0] cq_d_req_type ;
  wire [15:0] cq_d_reqr_id  ;
  wire [ 7:0] cq_d_tag      ;
  wire [ 2:0] cq_d_bar_id   ;
  wire [ 2:0] cq_d_tc       ;
  wire [ 2:0] cq_d_attr     ;

  wire [31:0] cq_data;

  wire       cq_sop        ;
  wire [3:0] cq_first_be   ;
  wire       cq_discontinue;

  reg [ 1:0] req_at       ;
  reg [31:0] req_addr     ;
  reg [10:0] req_dword_cnt;
  reg [ 3:0] req_type     ;
  reg [15:0] req_reqr_id  ;
  reg [ 7:0] req_tag      ;
  reg [ 2:0] req_bar_id   ;
  reg [ 2:0] req_tc       ;
  reg [ 2:0] req_attr     ;
  reg [ 3:0] req_first_be ;
  reg [31:0] req_data     ;


  wire [7:0] dummy_wstrb;

  reg [ 4:0] cpl_addr    ;
  reg [ 1:0] cpl_at      ;
  reg [ 2:0] cpl_byte_cnt;
  reg [15:0] cpl_rqer_id ;
  reg [78:0] cpl_tag     ;
  reg [ 2:0] cpl_tc      ;
  reg [ 2:0] cpl_attr    ;
  reg [31:0] cpl_data    ;


  enum {S_CQ_RESET, S_CQ_WAIT_FOR_REQ, S_CQ_STORE_RD_REQ, S_CQ_STORE_WR_REQ} cq_state;

  enum {S_CC_RESET, S_CC_WAIT_FOR_DATA, S_CC_SEND_CPL} cc_state;

  reg valid_rd_req      ;
  reg valid_wr_req      ;
  reg cpl_data_available;



  `define C_MEM_RD_REQ 4'b0000
  `define C_MEM_WR_REQ 4'b0001

  assign cq_d_at = m_axis_cq_tdata[1:0];
  assign cq_d_addr      = m_axis_cq_tdata[63:2];
  assign cq_d_dword_cnt = m_axis_cq_tdata[74:64];
  assign cq_d_req_type  = m_axis_cq_tdata[78:75];
  assign cq_d_reqr_id   = m_axis_cq_tdata[95:80];
  assign cq_d_tag       = m_axis_cq_tdata[103:96];
  assign cq_d_bar_id    = m_axis_cq_tdata[114:112];
  assign cq_d_tc        = m_axis_cq_tdata[123:121];
  assign cq_d_attr      = m_axis_cq_tdata[126:124];

  assign cq_data = m_axis_cq_tdata[159:128];

  assign cq_sop         = m_axis_cq_tuser[40];
  assign cq_first_be    = m_axis_cq_tuser[3:0];
  assign cq_discontinue = m_axis_cq_tuser[41];


  always_comb begin
    m_axi_lite_arprot = 2'b0;
    m_axi_lite_awprot = 2'b0;
    m_axi_lite_bready = 1'b1;
    md_error          = 1'b0;
  end

  // Decode valid read and write requests
  always_comb begin
    //
    if ((cq_d_req_type == `C_MEM_RD_REQ) && (cq_d_dword_cnt == 1) &&
      cq_sop && !cq_discontinue && m_axis_cq_tvalid && (cq_d_bar_id == 2)) begin
      valid_rd_req = 1'b1;
    end else begin
      valid_rd_req = 1'b0;
    end
    //
    if ((cq_d_req_type == `C_MEM_WR_REQ) && (cq_d_dword_cnt == 1) &&
      cq_sop && !cq_discontinue && m_axis_cq_tvalid && (cq_d_bar_id == 2)) begin
      valid_wr_req = 1'b1;
    end else begin
      valid_wr_req = 1'b0;
    end
  end



  //
  always_ff @(posedge user_clk, negedge reset_n) begin
    if (!reset_n) begin
      cq_state <= S_CQ_RESET;
    end else begin
      case (cq_state)
        //
        S_CQ_RESET : begin
          cq_state <= S_CQ_WAIT_FOR_REQ;
        end
        //
        S_CQ_WAIT_FOR_REQ : begin
          if (valid_rd_req) begin
            cq_state <= S_CQ_STORE_RD_REQ;
          end else if (valid_wr_req) begin
            cq_state <= S_CQ_STORE_WR_REQ;
          end
        end
        //
        S_CQ_STORE_WR_REQ : begin
          if (wa_fifo_tready && w_fifo_tready) begin
            cq_state <= S_CQ_WAIT_FOR_REQ;
          end
        end
        //
        S_CQ_STORE_RD_REQ : begin
          if (ra_fifo_tready && d_fifo_s_tready) begin
            cq_state <= S_CQ_WAIT_FOR_REQ;
          end
        end
        //
      endcase
    end
  end

  always_comb begin
    if (cq_state == S_CQ_WAIT_FOR_REQ) begin
      m_axis_cq_tready = 1'b1;
    end else begin
      m_axis_cq_tready = 1'b0;
    end
  end

  always_ff @(posedge user_clk) begin
    if ((cq_state==S_CQ_WAIT_FOR_REQ) && (valid_rd_req || valid_wr_req)) begin
      req_at        = cq_d_at;
      req_addr      = {cq_d_addr[29:0],2'b0};
      req_dword_cnt = cq_d_dword_cnt;
      req_type      = cq_d_req_type;
      req_reqr_id   = cq_d_reqr_id;
      req_tag       = cq_d_tag;
      req_bar_id    = cq_d_bar_id;
      req_tc        = cq_d_tc;
      req_attr      = cq_d_attr;
      req_first_be  = cq_first_be;
      req_data      = cq_data;
    end
  end

  always_comb begin
    //
    if ((cq_state==S_CQ_STORE_WR_REQ) && wa_fifo_tready && w_fifo_tready) begin
      wa_fifo_tvalid = 1'b1;
      w_fifo_tvalid  = 1'b1;
    end else begin
      wa_fifo_tvalid = 1'b0;
      w_fifo_tvalid  = 1'b0;
    end
    //
    if ((cq_state==S_CQ_STORE_RD_REQ) && ra_fifo_tready && d_fifo_s_tready) begin
      ra_fifo_tvalid  = 1'b1;
      d_fifo_s_tvalid = 1'b1;
    end else begin
      ra_fifo_tvalid  = 1'b0;
      d_fifo_s_tvalid = 1'b0;
    end
  end


  always_comb begin
    d_fifo_s_tdata[15:0]  = req_reqr_id;
    d_fifo_s_tdata[23:16] = req_tag;
    d_fifo_s_tdata[25:24] = req_at;
    d_fifo_s_tdata[28:26] = req_tc;
    d_fifo_s_tdata[31:29] = req_attr;

    d_fifo_s_tuser[7:0]  = {1'b0,req_addr[6:0]};
    d_fifo_s_tuser[11:8] = 4'h4; //  byte count
  end







  ////////////////////////
  //
  ////////////////////////

  always_comb begin
    if (r_fifo_m_tvalid && d_fifo_m_tvalid) begin
      cpl_data_available = 1'b1;
    end else begin
      cpl_data_available = 1'b0;
    end
  end



  always_ff @(posedge user_clk, negedge reset_n) begin
    if (!reset_n) begin
      cc_state <= S_CC_RESET;
    end else begin
      case (cc_state)
        //
        S_CC_RESET : begin
          cc_state <= S_CC_WAIT_FOR_DATA;
        end
        //
        S_CC_WAIT_FOR_DATA : begin
          if (cpl_data_available) begin
            cc_state <= S_CC_SEND_CPL;
          end
        end
        //
        S_CC_SEND_CPL : begin
          if (s_axis_cc_tready) begin
            cc_state <= S_CC_WAIT_FOR_DATA;
          end
        end
      endcase
    end
  end

  always_comb begin
    if (cpl_data_available) begin
      r_fifo_m_tready = 1'b1;
      d_fifo_m_tready = 1'b1;
    end else begin
      r_fifo_m_tready = 1'b0;
      d_fifo_m_tready = 1'b0;
    end
  end


  always_ff @(posedge user_clk) begin
    if ((cc_state==S_CC_WAIT_FOR_DATA) && cpl_data_available) begin

      cpl_rqer_id = d_fifo_m_tdata[15:0];
      cpl_tag     = d_fifo_m_tdata[23:16];
      cpl_at      = d_fifo_m_tdata[25:24];
      cpl_tc      = d_fifo_m_tdata[28:26];
      cpl_attr    = d_fifo_m_tdata[31:29];

      cpl_addr     = d_fifo_m_tuser[6:0];
      cpl_byte_cnt = d_fifo_m_tuser[11:8];

      cpl_data = r_fifo_m_tdata;
    end
  end



  always_comb begin
    if (cc_state == S_CC_SEND_CPL) begin
      s_axis_cc_tdata[6:0]     = cpl_addr;         // Lower Address
      s_axis_cc_tdata[7]       = 1'b0;
      s_axis_cc_tdata[9:8]     = cpl_at;                  // Address Type
      s_axis_cc_tdata[15:10]   = 6'b0;                  // Reserved
      s_axis_cc_tdata[28:16]   = {10'b0,cpl_byte_cnt};  // Byte Count
      s_axis_cc_tdata[29]      = 1'b0;                     // Locked Read Completion
      s_axis_cc_tdata[31:30]   = 2'b0;        // Reserved
      s_axis_cc_tdata[42:32]   = 11'b1;        // Dword Count
      s_axis_cc_tdata[45:43]   = 3'b0;              // Completion Status
      s_axis_cc_tdata[46]      = 1'b0;               // Poisoned Completion
      s_axis_cc_tdata[47]      = 1'b0;               // Reserved
      s_axis_cc_tdata[63:48]   = cpl_rqer_id;     // Requester ID
      s_axis_cc_tdata[71:64]   = cpl_tag;         // Tag
      s_axis_cc_tdata[87:72]   = 16'b0;           // Completer ID
      s_axis_cc_tdata[88]      = 1'b0;               // Completer ID Enable
      s_axis_cc_tdata[91:89]   = cpl_tc;           // Transaction Class
      s_axis_cc_tdata[94:92]   = cpl_attr;         // Attributes
      s_axis_cc_tdata[95]      = 1'b0;                 // Force ECRC
      s_axis_cc_tdata[127:96]  = cpl_data;
      s_axis_cc_tdata[255:128] = 128'b0;

      s_axis_cc_tuser[0]    = 1'b0;          // Discontinue
      s_axis_cc_tuser[32:1] = 32'b0;     // Reserved

      s_axis_cc_tkeep = 8'b00001111;
      s_axis_cc_tlast = 1'b1;
    end else begin
      s_axis_cc_tdata[255:0] = 256'b0;
      s_axis_cc_tuser[32:0]  = 33'b0;
      s_axis_cc_tkeep        = 8'b00000000;
      s_axis_cc_tlast        = 1'b0;

    end
  end

  always_comb begin
    if (cc_state == S_CC_SEND_CPL) begin
      s_axis_cc_tvalid = 1'b1;
    end else begin
      s_axis_cc_tvalid = 1'b0;
    end
  end


  axis_fifo_2clk_32d_12u wa_fifo (
    .s_aclk       (user_clk          ), // input wire s_aclk
    .s_aresetn    (reset_n           ), // input wire s_aresetn
    .s_axis_tvalid(wa_fifo_tvalid    ), // input wire s_axis_tvalid
    .s_axis_tready(wa_fifo_tready    ), // output wire s_axis_tready
    .s_axis_tdata (req_addr          ), // input wire [31 : 0] s_axis_tdata
    .s_axis_tuser (12'b0             ), // input wire [3 : 0] s_axis_tuser
    
    .m_aclk       (m_axi_lite_aclk   ), // input wire m_aclk
    .m_axis_tvalid(m_axi_lite_awvalid), // output wire m_axis_tvalid
    .m_axis_tready(m_axi_lite_awready), // input wire m_axis_tready
    .m_axis_tdata (m_axi_lite_awaddr ), // output wire [31 : 0] m_axis_tdata
    .m_axis_tuser (                  )  // output wire [3 : 0] m_axis_tuser
  );

  axis_fifo_2clk_32d_12u w_fifo (
    .s_aclk       (user_clk                      ), // input wire s_aclk
    .s_aresetn    (reset_n                       ), // input wire s_aresetn
    .s_axis_tvalid(w_fifo_tvalid                 ), // input wire s_axis_tvalid
    .s_axis_tready(w_fifo_tready                 ), // output wire s_axis_tready
    .s_axis_tdata (req_data                      ), // input wire [31 : 0] s_axis_tdata
    .s_axis_tuser ({8'b0,req_first_be}           ), // input wire [3 : 0] s_axis_tuser
    
    .m_aclk       (m_axi_lite_aclk               ), // input wire m_aclk
    .m_axis_tvalid(m_axi_lite_wvalid             ), // output wire m_axis_tvalid
    .m_axis_tready(m_axi_lite_wready             ), // input wire m_axis_tready
    .m_axis_tdata (m_axi_lite_wdata              ), // output wire [31 : 0] m_axis_tdata
    .m_axis_tuser ({dummy_wstrb,m_axi_lite_wstrb})  // output wire [3 : 0] m_axis_tuser
  );

  axis_fifo_2clk_32d_12u ar_fifo (
    .s_aclk       (user_clk          ), // input wire s_aclk
    .s_aresetn    (reset_n           ), // input wire s_aresetn
    .s_axis_tvalid(ra_fifo_tvalid    ), // input wire s_axis_tvalid
    .s_axis_tready(ra_fifo_tready    ), // output wire s_axis_tready
    .s_axis_tdata (req_addr          ), // input wire [31 : 0] s_axis_tdata
    .s_axis_tuser (12'b0             ), // input wire [3 : 0] s_axis_tuser
    
    .m_aclk       (m_axi_lite_aclk   ), // input wire m_aclk
    .m_axis_tvalid(m_axi_lite_arvalid), // output wire m_axis_tvalid
    .m_axis_tready(m_axi_lite_arready), // input wire m_axis_tready
    .m_axis_tdata (m_axi_lite_araddr ), // output wire [31 : 0] m_axis_tdata
    .m_axis_tuser (                  )  // output wire [3 : 0] m_axis_tuser
  );

  axis_fifo_2clk_32d_12u r_fifo (
    .s_aclk       (m_axi_lite_aclk         ), // input wire s_aclk
    .s_aresetn    (m_axi_lite_aresetn      ), // input wire s_aresetn
    .s_axis_tvalid(m_axi_lite_rvalid       ), // input wire s_axis_tvalid
    .s_axis_tready(m_axi_lite_rready       ), // output wire s_axis_tready
    .s_axis_tdata (m_axi_lite_rdata        ), // input wire [31 : 0] s_axis_tdata
    .s_axis_tuser ({10'b0,m_axi_lite_rresp}), // input wire [3 : 0] s_axis_tuser
    
    .m_aclk       (user_clk                ), // input wire m_aclk
    .m_axis_tvalid(r_fifo_m_tvalid         ), // output wire m_axis_tvalid
    .m_axis_tready(r_fifo_m_tready         ), // input wire m_axis_tready
    .m_axis_tdata (r_fifo_m_tdata          ), // output wire [31 : 0] m_axis_tdata
    .m_axis_tuser (r_fifo_m_tuser          )  // output wire [3 : 0] m_axis_tuser
  );

  axis_fifo_2clk_32d_12u d_fifo (
    .s_aclk       (user_clk       ), // input wire s_aclk
    .s_aresetn    (reset_n        ), // input wire s_aresetn
    .s_axis_tvalid(d_fifo_s_tvalid), // input wire s_axis_tvalid
    .s_axis_tready(d_fifo_s_tready), // output wire s_axis_tready
    .s_axis_tdata (d_fifo_s_tdata ), // input wire [31 : 0] s_axis_tdata
    .s_axis_tuser (d_fifo_s_tuser ),
    
    .m_aclk       (user_clk       ),
    .m_axis_tvalid(d_fifo_m_tvalid), // output wire m_axis_tvalid
    .m_axis_tready(d_fifo_m_tready), // input wire m_axis_tready
    .m_axis_tdata (d_fifo_m_tdata ), // output wire [31 : 0] m_axis_tdata
    .m_axis_tuser (d_fifo_m_tuser )
  );

endmodule
