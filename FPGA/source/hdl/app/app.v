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

`default_nettype wire


module app #(
  parameter C_M_AXI_LITE_ADDR_WIDTH = 9 ,
  parameter C_M_AXI_LITE_DATA_WIDTH = 32
) (
  // AXI-LITE MASTER interface
  // clk && rst
  input                                         m_axi_lite_aclk   ,
  input                                         m_axi_lite_aresetn,
  // AXI4 Read Address Channel
  output                                        m_axi_lite_arready,
  input                                         m_axi_lite_arvalid,
  input       [    C_M_AXI_LITE_ADDR_WIDTH-1:0] m_axi_lite_araddr ,
  input       [                            2:0] m_axi_lite_arprot ,
  // AXI4 Read Data Channel
  input                                         m_axi_lite_rready ,
  output                                        m_axi_lite_rvalid ,
  output      [    C_M_AXI_LITE_DATA_WIDTH-1:0] m_axi_lite_rdata  ,
  output      [                            1:0] m_axi_lite_rresp  ,
  // AXI4 Write Address Channel
  output                                        m_axi_lite_awready,
  input                                         m_axi_lite_awvalid,
  input       [    C_M_AXI_LITE_ADDR_WIDTH-1:0] m_axi_lite_awaddr ,
  input       [                            2:0] m_axi_lite_awprot ,
  // AXI4 Write Data Channel
  output                                        m_axi_lite_wready ,
  input                                         m_axi_lite_wvalid ,
  input       [    C_M_AXI_LITE_DATA_WIDTH-1:0] m_axi_lite_wdata  ,
  input       [(C_M_AXI_LITE_DATA_WIDTH/8)-1:0] m_axi_lite_wstrb  ,
  // AXI4 Write Response Channel
  input                                         m_axi_lite_bready ,
  output                                        m_axi_lite_bvalid ,
  output      [                            1:0] m_axi_lite_bresp  ,
  // GPIO
  input  wire [                            1:0] gpio_io_i         ,
  output wire [                            1:0] gpio_io_t         ,
  output wire [                            1:0] gpio_io_o         ,
  // Dma interface
  input  wire                                   s2c_tvalid        ,
  output wire                                   s2c_tready        ,
  input  wire [                          255:0] s2c_tdata         ,
  input  wire                                   s2c_tlast         ,
  input  wire [                           31:0] s2c_tkeep         ,
  input  wire                                   c2s_tready        ,
  output wire [                          255:0] c2s_tdata         ,
  output wire                                   c2s_tlast         ,
  output wire                                   c2s_tvalid        ,
  output wire [                           31:0] c2s_tkeep
);


// GPIO
  axi_gpio_0 axi_gpio_0_i (
    .s_axi_aclk   (m_axi_lite_aclk   ), // input wire s_axi_aclk
    .s_axi_aresetn(m_axi_lite_aresetn), // input wire s_axi_aresetn
    .s_axi_awaddr (m_axi_lite_awaddr ), // input wire [8 : 0] s_axi_awaddr
    .s_axi_awvalid(m_axi_lite_awvalid), // input wire s_axi_awvalid
    .s_axi_awready(m_axi_lite_awready), // output wire s_axi_awready
    .s_axi_wdata  (m_axi_lite_wdata  ), // input wire [31 : 0] s_axi_wdata
    .s_axi_wstrb  (m_axi_lite_wstrb  ), // input wire [3 : 0] s_axi_wstrb
    .s_axi_wvalid (m_axi_lite_wvalid ), // input wire s_axi_wvalid
    .s_axi_wready (m_axi_lite_wready ), // output wire s_axi_wready
    .s_axi_bresp  (m_axi_lite_bresp  ), // output wire [1 : 0] s_axi_bresp
    .s_axi_bvalid (m_axi_lite_bvalid ), // output wire s_axi_bvalid
    .s_axi_bready (m_axi_lite_bready ), // input wire s_axi_bready
    .s_axi_araddr (m_axi_lite_araddr ), // input wire [8 : 0] s_axi_araddr
    .s_axi_arvalid(m_axi_lite_arvalid), // input wire s_axi_arvalid
    .s_axi_arready(m_axi_lite_arready), // output wire s_axi_arready
    .s_axi_rdata  (m_axi_lite_rdata  ), // output wire [31 : 0] s_axi_rdata
    .s_axi_rresp  (m_axi_lite_rresp  ), // output wire [1 : 0] s_axi_rresp
    .s_axi_rvalid (m_axi_lite_rvalid ), // output wire s_axi_rvalid
    .s_axi_rready (m_axi_lite_rready ), // input wire s_axi_rready
    .gpio_io_i    (gpio_io_i         ), // input wire [1 : 0] gpio_io_i
    .gpio_io_o    (gpio_io_o         ), // output wire [1 : 0] gpio_io_o
    .gpio_io_t    (gpio_io_t         )  // output wire [1 : 0] gpio_io_t
  );

  ///////////////
  ///// DMA logic
  reg [255:0] c2s_tdata_r;


  //S2C is a sink
  assign s2c_tready = 1'b1;

  // C2S is a 32 bit counter
  assign c2s_tkeep = 32'hffffffff;
  assign c2s_tlast = 1'b0;

  always @(negedge m_axi_lite_aresetn or posedge m_axi_lite_aclk) begin
    if(!m_axi_lite_aresetn) begin
      c2s_tdata_r <= 256'h0;
    end else begin
      if(c2s_tready) begin
        // The most significant bits will be set to 0
        c2s_tdata_r[31:0] <= c2s_tdata_r[31:0] + 1; // The 32 less significant bits will store a counter.
      end
    end
  end

  assign c2s_tdata  = c2s_tdata_r;
  assign c2s_tvalid = 1'b1;

endmodule