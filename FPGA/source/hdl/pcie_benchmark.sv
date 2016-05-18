//
// Copyright (c) 2015
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
//


`timescale 1ps / 1ps
`default_nettype wire


module pcie_benchmark (
  // PCIe
  input  wire       pcie_refclk_p,
  input  wire       pcie_refclk_n,
  input  wire       pcie_rst_n   ,
  input  wire [7:0] pcie_rx_p    ,
  input  wire [7:0] pcie_rx_n    ,
  output wire [7:0] pcie_tx_p    ,
  output wire [7:0] pcie_tx_n    ,
  // LEDs
  output wire [1:0] led          ,
  // Buttons
  input  wire [1:0] button
);


  wire pcie_user_clk    ;
  wire pcie_user_reset  ;
  wire pcie_user_lnk_up ;
  wire pcie_user_app_rdy;


  //----------------------------------------------------------------------------------------------------------------//
  //  AXI Interface                                                                                                 //
  //----------------------------------------------------------------------------------------------------------------//

  wire         s_axis_rq_tlast ;
  wire [255:0] s_axis_rq_tdata ;
  wire [ 59:0] s_axis_rq_tuser ;
  wire [  7:0] s_axis_rq_tkeep ;
  wire         s_axis_rq_tready;
  wire         s_axis_rq_tvalid;

  wire [255:0] m_axis_rc_tdata ;
  wire [ 74:0] m_axis_rc_tuser ;
  wire         m_axis_rc_tlast ;
  wire [  7:0] m_axis_rc_tkeep ;
  wire         m_axis_rc_tvalid;
  wire         m_axis_rc_tready;


  wire [255:0] m_axis_cq_tdata ;
  wire [ 84:0] m_axis_cq_tuser ;
  wire         m_axis_cq_tlast ;
  wire [  7:0] m_axis_cq_tkeep ;
  wire         m_axis_cq_tvalid;
  wire         m_axis_cq_tready;

  wire [255:0] s_axis_cc_tdata ;
  wire [ 32:0] s_axis_cc_tuser ;
  wire         s_axis_cc_tlast ;
  wire [  7:0] s_axis_cc_tkeep ;
  wire         s_axis_cc_tvalid;
  wire         s_axis_cc_tready;

  wire [ 1:0] cfg_interrupt_msix_enable   ;
  wire [ 1:0] cfg_interrupt_msix_mask     ;
  wire [ 5:0] cfg_interrupt_msix_vf_enable;
  wire [ 5:0] cfg_interrupt_msix_vf_mask  ;
  wire [31:0] cfg_interrupt_msix_data     ;
  wire [63:0] cfg_interrupt_msix_address  ;
  wire        cfg_interrupt_msix_int      ;
  wire        cfg_interrupt_msix_sent     ;
  wire        cfg_interrupt_msix_fail     ;

  wire [1:0] pcie_tfc_nph_av;
  wire [1:0] pcie_tfc_npd_av;
  ////////////////////////////////
  // AXI4-LITE MASTER interface //
  ////////////////////////////////
  // Clock and Reset
  wire m_axi_lite_aclk   ;
  wire m_axi_lite_aresetn;
  // Read Address Channel
  wire        m_axi_lite_arready;
  wire        m_axi_lite_arvalid;
  wire [31:0] m_axi_lite_araddr ;
  wire [ 2:0] m_axi_lite_arprot ;
  // Read Data Channel
  wire        m_axi_lite_rready;
  wire        m_axi_lite_rvalid;
  wire [31:0] m_axi_lite_rdata ;
  wire [ 1:0] m_axi_lite_rresp ;
  // Write Address Channel
  wire        m_axi_lite_awready;
  wire        m_axi_lite_awvalid;
  wire [31:0] m_axi_lite_awaddr ;
  wire [ 2:0] m_axi_lite_awprot ;
  // Write Data Channel
  wire        m_axi_lite_wready;
  wire        m_axi_lite_wvalid;
  wire [31:0] m_axi_lite_wdata ;
  wire [ 3:0] m_axi_lite_wstrb ;
  // Write Response Channel
  wire       m_axi_lite_bready;
  wire       m_axi_lite_bvalid;
  wire [1:0] m_axi_lite_bresp ;

  ////////////////////////////
  // AXI4-Stream interfaces //
  ////////////////////////////
  wire         s2c_tvalid;
  wire         s2c_tready;
  wire [255:0] s2c_tdata ;
  wire         s2c_tlast ;
  wire [ 31:0] s2c_tkeep ;
  wire         c2s_tready;
  wire [255:0] c2s_tdata ;
  wire         c2s_tlast ;
  wire         c2s_tvalid;
  wire [ 31:0] c2s_tkeep ;



  pcie_ep_wrapper pcie_ep_wrapper_i (
    .pcie_tx_p                   (pcie_tx_p                   ), // output [7:0]
    .pcie_tx_n                   (pcie_tx_n                   ), // output [7:0]
    
    .pcie_rx_p                   (pcie_rx_p                   ), // input  [7:0]
    .pcie_rx_n                   (pcie_rx_n                   ), // input  [7:0]
    
    .pcie_refclk_p               (pcie_refclk_p               ), // input
    .pcie_refclk_n               (pcie_refclk_n               ),
    .pcie_rst_n                  (pcie_rst_n                  ), // input
    
    .user_clk                    (pcie_user_clk               ), // output
    .user_reset                  (pcie_user_reset             ), // output
    .user_lnk_up                 (pcie_user_lnk_up            ), // output
    .user_app_rdy                (pcie_user_app_rdy           ), // output
    
    .s_axis_rq_tlast             (s_axis_rq_tlast             ), // input
    .s_axis_rq_tdata             (s_axis_rq_tdata             ), // input  [255:0]
    .s_axis_rq_tuser             (s_axis_rq_tuser             ), // input  [59:0]
    .s_axis_rq_tkeep             (s_axis_rq_tkeep             ), // input  [31:0]
    .s_axis_rq_tready            (s_axis_rq_tready            ), // output [3:0]
    .s_axis_rq_tvalid            (s_axis_rq_tvalid            ), // input
    
    .m_axis_rc_tdata             (m_axis_rc_tdata             ), // output [255:0]
    .m_axis_rc_tuser             (m_axis_rc_tuser             ), // output [74:0]
    .m_axis_rc_tlast             (m_axis_rc_tlast             ), // output
    .m_axis_rc_tkeep             (m_axis_rc_tkeep             ), // output [31:0]
    .m_axis_rc_tvalid            (m_axis_rc_tvalid            ), // output
    .m_axis_rc_tready            (m_axis_rc_tready            ), // input  [21:0]
    
    .m_axis_cq_tdata             (m_axis_cq_tdata             ), // output [255:0]
    .m_axis_cq_tuser             (m_axis_cq_tuser             ), // output [84:0]
    .m_axis_cq_tlast             (m_axis_cq_tlast             ), // output
    .m_axis_cq_tkeep             (m_axis_cq_tkeep             ), // output [31:0]
    .m_axis_cq_tvalid            (m_axis_cq_tvalid            ), // output
    .m_axis_cq_tready            (m_axis_cq_tready            ), // input  [21:0]
    
    .s_axis_cc_tdata             (s_axis_cc_tdata             ), // input  [255:0]
    .s_axis_cc_tuser             (s_axis_cc_tuser             ), // input  [32:0]
    .s_axis_cc_tlast             (s_axis_cc_tlast             ), // input
    .s_axis_cc_tkeep             (s_axis_cc_tkeep             ), // input  [31:0]
    .s_axis_cc_tvalid            (s_axis_cc_tvalid            ), // input
    .s_axis_cc_tready            (s_axis_cc_tready            ), // output [3:0]
    
    
    .cfg_interrupt_msix_enable   (cfg_interrupt_msix_enable   ), // output [1:0]
    .cfg_interrupt_msix_mask     (cfg_interrupt_msix_mask     ), // output [1:0]
    .cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable), // output [5:0]
    .cfg_interrupt_msix_vf_mask  (cfg_interrupt_msix_vf_mask  ), // output [5:0]
    .cfg_interrupt_msix_data     (cfg_interrupt_msix_data     ), // input  [31:0]
    .cfg_interrupt_msix_address  (cfg_interrupt_msix_address  ), // input  [63:0]
    .cfg_interrupt_msix_int      (cfg_interrupt_msix_int      ), // input
    .cfg_interrupt_msix_sent     (cfg_interrupt_msix_sent     ), // output
    .cfg_interrupt_msix_fail     (cfg_interrupt_msix_fail     ), // output
    .pcie_tfc_nph_av             (pcie_tfc_nph_av             ), // output [1:0]
    .pcie_tfc_npd_av             (pcie_tfc_npd_av             )  // output [1:0]
  );

  ////////////////
  // PCIe reset //
  ////////////////
  reg pcie_reset;

  always @(posedge pcie_user_clk) begin
    if (pcie_user_reset || !pcie_user_app_rdy) begin
      pcie_reset <= 1;
    end else if (pcie_user_app_rdy) begin
      pcie_reset <= 0;
    end
  end

  //////////////////////////////
  // AXI-Lite Clock and Reset //
  //////////////////////////////

  assign m_axi_lite_aclk    = pcie_user_clk;
  assign m_axi_lite_aresetn = !pcie_reset;


  pcie_controller pcie_controller_i (
    // Clock and reset
    .pcie_clk                    (pcie_user_clk               ),
    .pcie_reset                  (pcie_reset                  ),
    // Requester
    .s_axis_rq_tlast             (s_axis_rq_tlast             ),
    .s_axis_rq_tdata             (s_axis_rq_tdata             ),
    .s_axis_rq_tuser             (s_axis_rq_tuser             ),
    .s_axis_rq_tkeep             (s_axis_rq_tkeep             ),
    .s_axis_rq_tready            (s_axis_rq_tready            ),
    .s_axis_rq_tvalid            (s_axis_rq_tvalid            ),
    .m_axis_rc_tdata             (m_axis_rc_tdata             ),
    .m_axis_rc_tuser             (m_axis_rc_tuser             ),
    .m_axis_rc_tlast             (m_axis_rc_tlast             ),
    .m_axis_rc_tkeep             (m_axis_rc_tkeep             ),
    .m_axis_rc_tvalid            (m_axis_rc_tvalid            ),
    .m_axis_rc_tready            (m_axis_rc_tready            ),
    // Completer
    .m_axis_cq_tdata             (m_axis_cq_tdata             ),
    .m_axis_cq_tuser             (m_axis_cq_tuser             ),
    .m_axis_cq_tlast             (m_axis_cq_tlast             ),
    .m_axis_cq_tkeep             (m_axis_cq_tkeep             ),
    .m_axis_cq_tvalid            (m_axis_cq_tvalid            ),
    .m_axis_cq_tready            (m_axis_cq_tready            ),
    .s_axis_cc_tdata             (s_axis_cc_tdata             ),
    .s_axis_cc_tuser             (s_axis_cc_tuser             ),
    .s_axis_cc_tlast             (s_axis_cc_tlast             ),
    .s_axis_cc_tkeep             (s_axis_cc_tkeep             ),
    .s_axis_cc_tvalid            (s_axis_cc_tvalid            ),
    .s_axis_cc_tready            (s_axis_cc_tready            ),
    // MSI-X
    .cfg_interrupt_msix_enable   (cfg_interrupt_msix_enable   ),
    .cfg_interrupt_msix_mask     (cfg_interrupt_msix_mask     ),
    .cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable),
    .cfg_interrupt_msix_vf_mask  (cfg_interrupt_msix_vf_mask  ),
    .cfg_interrupt_msix_data     (cfg_interrupt_msix_data     ),
    .cfg_interrupt_msix_address  (cfg_interrupt_msix_address  ),
    .cfg_interrupt_msix_int      (cfg_interrupt_msix_int      ),
    .cfg_interrupt_msix_sent     (cfg_interrupt_msix_sent     ),
    .cfg_interrupt_msix_fail     (cfg_interrupt_msix_fail     ),
    // Credits
    .pcie_tfc_nph_av             (pcie_tfc_nph_av             ),
    .pcie_tfc_npd_av             (pcie_tfc_npd_av             ),
    // AXI4-Lite interface //
    .m_axi_lite_aclk             (m_axi_lite_aclk             ),
    .m_axi_lite_aresetn          (m_axi_lite_aresetn          ),
    .m_axi_lite_arready          (m_axi_lite_arready          ),
    .m_axi_lite_arvalid          (m_axi_lite_arvalid          ),
    .m_axi_lite_araddr           (m_axi_lite_araddr           ),
    .m_axi_lite_arprot           (m_axi_lite_arprot           ),
    .m_axi_lite_rready           (m_axi_lite_rready           ),
    .m_axi_lite_rvalid           (m_axi_lite_rvalid           ),
    .m_axi_lite_rdata            (m_axi_lite_rdata            ),
    .m_axi_lite_rresp            (m_axi_lite_rresp            ),
    .m_axi_lite_awready          (m_axi_lite_awready          ),
    .m_axi_lite_awvalid          (m_axi_lite_awvalid          ),
    .m_axi_lite_awaddr           (m_axi_lite_awaddr           ),
    .m_axi_lite_awprot           (m_axi_lite_awprot           ),
    .m_axi_lite_wready           (m_axi_lite_wready           ),
    .m_axi_lite_wvalid           (m_axi_lite_wvalid           ),
    .m_axi_lite_wdata            (m_axi_lite_wdata            ),
    .m_axi_lite_wstrb            (m_axi_lite_wstrb            ),
    .m_axi_lite_bready           (m_axi_lite_bready           ),
    .m_axi_lite_bvalid           (m_axi_lite_bvalid           ),
    .m_axi_lite_bresp            (m_axi_lite_bresp            ),
    
    
    // Axi 4 stream interface 
    .s2c_tvalid                  (s2c_tvalid                  ),
    .s2c_tready                  (s2c_tready                  ),
    .s2c_tdata                   (s2c_tdata                   ),
    .s2c_tlast                   (s2c_tlast                   ),
    .s2c_tkeep                   (s2c_tkeep                   ),
    .c2s_tready                  (c2s_tready                  ),
    .c2s_tdata                   (c2s_tdata                   ),
    .c2s_tlast                   (c2s_tlast                   ),
    .c2s_tvalid                  (c2s_tvalid                  ),
    .c2s_tkeep                   (c2s_tkeep                   )
  );


  app app_i (
    .m_axi_lite_aclk   (m_axi_lite_aclk       ),
    .m_axi_lite_aresetn(m_axi_lite_aresetn    ),
    .m_axi_lite_arready(m_axi_lite_arready    ),
    .m_axi_lite_arvalid(m_axi_lite_arvalid    ),
    .m_axi_lite_araddr (m_axi_lite_araddr[8:0]),
    .m_axi_lite_arprot (m_axi_lite_arprot     ),
    .m_axi_lite_rready (m_axi_lite_rready     ),
    .m_axi_lite_rvalid (m_axi_lite_rvalid     ),
    .m_axi_lite_rdata  (m_axi_lite_rdata      ),
    .m_axi_lite_rresp  (m_axi_lite_rresp      ),
    .m_axi_lite_awready(m_axi_lite_awready    ),
    .m_axi_lite_awvalid(m_axi_lite_awvalid    ),
    .m_axi_lite_awaddr (m_axi_lite_awaddr[8:0]),
    .m_axi_lite_awprot (m_axi_lite_awprot     ),
    .m_axi_lite_wready (m_axi_lite_wready     ),
    .m_axi_lite_wvalid (m_axi_lite_wvalid     ),
    .m_axi_lite_wdata  (m_axi_lite_wdata      ),
    .m_axi_lite_wstrb  (m_axi_lite_wstrb      ),
    .m_axi_lite_bready (m_axi_lite_bready     ),
    .m_axi_lite_bvalid (m_axi_lite_bvalid     ),
    .m_axi_lite_bresp  (m_axi_lite_bresp      ),
    
    .gpio_io_i         (button                ), // input wire [1 : 0] gpio_io_i
    .gpio_io_o         (led[1:0]              ), // output wire [1 : 0] gpio_io_o
    .gpio_io_t         (                      ), // output wire [1 : 0] gpio_io_t
    
    .s2c_tvalid        (s2c_tvalid            ),
    .s2c_tready        (s2c_tready            ),
    .s2c_tdata         (s2c_tdata             ),
    .s2c_tlast         (s2c_tlast             ),
    .s2c_tkeep         (s2c_tkeep             ),
    .c2s_tready        (c2s_tready            ),
    .c2s_tdata         (c2s_tdata             ),
    .c2s_tlast         (c2s_tlast             ),
    .c2s_tvalid        (c2s_tvalid            ),
    .c2s_tkeep         (c2s_tkeep             )
  );

endmodule