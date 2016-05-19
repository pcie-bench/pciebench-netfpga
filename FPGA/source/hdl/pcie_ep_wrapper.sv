//
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
//


`timescale 1ps / 1ps
`default_nettype none
`define VERSION_VIVADO_2014_4


module pcie_ep_wrapper (
  // PCIe
  input  wire         pcie_refclk_p               ,
  input  wire         pcie_refclk_n               ,
  input  wire         pcie_rst_n                  ,
  input  wire [  7:0] pcie_rx_p                   ,
  input  wire [  7:0] pcie_rx_n                   ,
  output wire [  7:0] pcie_tx_p                   ,
  output wire [  7:0] pcie_tx_n                   ,
  // Common
  output wire         user_clk                    ,
  output wire         user_reset                  ,
  output wire         user_lnk_up                 ,
  output wire         user_app_rdy                ,
  input  wire         s_axis_rq_tlast             ,
  input  wire [255:0] s_axis_rq_tdata             ,
  input  wire [ 59:0] s_axis_rq_tuser             ,
  input  wire [  7:0] s_axis_rq_tkeep             ,
  output wire         s_axis_rq_tready            ,
  input  wire         s_axis_rq_tvalid            ,
  output wire [255:0] m_axis_rc_tdata             ,
  output wire [ 74:0] m_axis_rc_tuser             ,
  output wire         m_axis_rc_tlast             ,
  output wire [  7:0] m_axis_rc_tkeep             ,
  output wire         m_axis_rc_tvalid            ,
  input  wire         m_axis_rc_tready            ,
  output wire [255:0] m_axis_cq_tdata             ,
  output wire [ 84:0] m_axis_cq_tuser             ,
  output wire         m_axis_cq_tlast             ,
  output wire [  7:0] m_axis_cq_tkeep             ,
  output wire         m_axis_cq_tvalid            ,
  input  wire         m_axis_cq_tready            ,
  input  wire [255:0] s_axis_cc_tdata             ,
  input  wire [ 32:0] s_axis_cc_tuser             ,
  input  wire         s_axis_cc_tlast             ,
  input  wire [  7:0] s_axis_cc_tkeep             ,
  input  wire         s_axis_cc_tvalid            ,
  output wire         s_axis_cc_tready            ,
  output wire [  1:0] cfg_interrupt_msix_enable   ,
  output wire [  1:0] cfg_interrupt_msix_mask     ,
  output wire [  5:0] cfg_interrupt_msix_vf_enable,
  output wire [  5:0] cfg_interrupt_msix_vf_mask  ,
  input  wire [ 31:0] cfg_interrupt_msix_data     ,
  input  wire [ 63:0] cfg_interrupt_msix_address  ,
  input  wire         cfg_interrupt_msix_int      ,
  output wire         cfg_interrupt_msix_sent     ,
  output wire         cfg_interrupt_msix_fail     ,
  output wire [  1:0] pcie_tfc_nph_av             ,
  output wire [  1:0] pcie_tfc_npd_av
);



  `define PCI_EXP_EP_OUI                           24'h000A35
  `define PCI_EXP_EP_DSN_1                         {{8'h1},`PCI_EXP_EP_OUI}
  `define PCI_EXP_EP_DSN_2                         32'h00000001
  localparam TCQ = 1;

  wire       sys_rst_n_c           ;
  wire       sys_clk               ;
  wire [3:0] s_axis_rq_tready_array;
  wire [3:0] s_axis_cc_tready_array;

  `ifndef VERSION_VIVADO_2014_4
    wire m_axis_cq_tready_array;
    wire m_axis_rc_tready_array;
  `else
    wire [21:0] m_axis_cq_tready_array;
    wire [21:0] m_axis_rc_tready_array;
  `endif


  wire pipe_mmcm_rst_n;
  assign pipe_mmcm_rst_n = 1'b1;

  wire [3:0] pcie_rq_seq_num    ;
  wire       pcie_rq_seq_num_vld;
  wire [5:0] pcie_rq_tag        ;
  wire       pcie_rq_tag_vld    ;

  wire       pcie_cq_np_req      ; // input
  wire [5:0] pcie_cq_np_req_count; // output

  wire cfg_phy_link_down; // output
  // output  [1:0]
  wire [ 3:0] cfg_negotiated_width    ; // output
  wire [ 2:0] cfg_current_speed       ; // output
  wire [ 2:0] cfg_max_payload         ; // output
  wire [ 2:0] cfg_max_read_req        ; // output
  wire [ 7:0] cfg_function_status     ; // output
  wire [ 5:0] cfg_function_power_state; // output
  wire [11:0] cfg_vf_status           ; // output
  wire [17:0] cfg_vf_power_state      ; // output
  wire [ 1:0] cfg_link_power_state    ; // output

  // Error Reporting Inte
  wire cfg_err_cor_out     ; // output
  wire cfg_err_nonfatal_out; // output
  wire cfg_err_fatal_out   ; // output

  wire       cfg_ltr_enable         ; // output
  wire [5:0] cfg_ltssm_state        ; // output
  wire [1:0] cfg_rcb_status         ; // output
  wire [1:0] cfg_dpa_substate_change; // output
  wire [1:0] cfg_obff_enable        ; // output
  wire       cfg_pl_status_change   ; // output

  wire [ 1:0] cfg_tph_requester_enable   ; // output
  wire [ 5:0] cfg_tph_st_mode            ; // output
  wire [ 5:0] cfg_vf_tph_requester_enable; // output
  wire [17:0] cfg_vf_tph_st_mode         ; // output

  // Management Interface
  reg  [18:0] cfg_mgmt_addr                   ; // input
  reg         cfg_mgmt_write                  ; // input
  reg  [31:0] cfg_mgmt_write_data             ; // input
  reg  [ 3:0] cfg_mgmt_byte_enable            ; // input
  reg         cfg_mgmt_read                   ; // input
  wire [31:0] cfg_mgmt_read_data              ; // output
  wire        cfg_mgmt_read_write_done        ; // output
  wire        cfg_mgmt_type1_cfg_reg_access   ; // input
  wire        cfg_msg_received                ; // output
  wire [ 7:0] cfg_msg_received_data           ; // output
  wire [ 4:0] cfg_msg_received_type           ; // output
  wire        cfg_msg_transmit                ; // input
  wire [ 2:0] cfg_msg_transmit_type           ; // input
  wire [31:0] cfg_msg_transmit_data           ; // input
  wire        cfg_msg_transmit_done           ; // output
  wire [ 7:0] cfg_fc_ph                       ; // output
  wire [11:0] cfg_fc_pd                       ; // output
  wire [ 7:0] cfg_fc_nph                      ; // output
  wire [11:0] cfg_fc_npd                      ; // output
  wire [ 7:0] cfg_fc_cplh                     ; // output
  wire [11:0] cfg_fc_cpld                     ; // output
  wire [ 2:0] cfg_fc_sel                      ; // input
  wire [ 2:0] cfg_per_func_status_control     ; // input
  wire [15:0] cfg_per_func_status_data        ; // output
  wire [15:0] cfg_subsys_vend_id              ; // input
  wire        cfg_hot_reset_out               ; // output
  wire        cfg_config_space_enable         ; // input
  wire        cfg_req_pm_transition_l23_ready ; // input
  wire        cfg_hot_reset_in                ; // input
  wire [ 7:0] cfg_ds_port_number              ; // input
  wire [ 7:0] cfg_ds_bus_number               ; // input
  wire [ 4:0] cfg_ds_device_number            ; // input
  wire [ 2:0] cfg_ds_function_number          ; // input
  wire [ 2:0] cfg_per_function_number         ; // input
  wire        cfg_per_function_output_request ; // input
  wire        cfg_per_function_update_done    ; // output
  wire [63:0] cfg_dsn                         ; // input
  wire        cfg_power_state_change_interrupt; // output
  reg         cfg_power_state_change_ack      ; // input
  wire        cfg_err_cor_in                  ; // input
  wire        cfg_err_uncor_in                ; // input
  wire [ 1:0] cfg_flr_in_process              ; // output
  wire [ 1:0] cfg_flr_done                    ; // input
  wire [ 5:0] cfg_vf_flr_in_process           ; // output
  wire [ 5:0] cfg_vf_flr_done                 ; // input
  wire        cfg_link_training_enable        ; // input
  wire        cfg_ext_read_received           ; // output
  wire        cfg_ext_write_received          ; // output
  wire [ 9:0] cfg_ext_register_number         ; // output
  wire [ 7:0] cfg_ext_function_number         ; // output
  wire [31:0] cfg_ext_write_data              ; // output
  wire [ 3:0] cfg_ext_write_byte_enable       ; // output
  wire [31:0] cfg_ext_read_data               ; // input
  wire        cfg_ext_read_data_valid         ; // input



  wire [ 3:0] cfg_interrupt_int                ; // input
  wire [ 1:0] cfg_interrupt_pending            ; // input
  wire        cfg_interrupt_sent               ; // output
  wire [ 1:0] cfg_interrupt_msi_enable         ; // output
  wire [ 5:0] cfg_interrupt_msi_vf_enable      ; // output
  wire [ 5:0] cfg_interrupt_msi_mmenable       ; // output
  wire        cfg_interrupt_msi_mask_update    ; // output
  wire [31:0] cfg_interrupt_msi_data           ; // output
  wire [ 3:0] cfg_interrupt_msi_select         ; // input
  wire [31:0] cfg_interrupt_msi_int            ; // input
  wire [63:0] cfg_interrupt_msi_pending_status ; // input
  wire        cfg_interrupt_msi_sent           ; // output
  wire        cfg_interrupt_msi_fail           ; // output
  wire [ 2:0] cfg_interrupt_msi_attr           ; // input
  wire        cfg_interrupt_msi_tph_present    ; // input
  wire [ 1:0] cfg_interrupt_msi_tph_type       ; // input
  wire [ 8:0] cfg_interrupt_msi_tph_st_tag     ; // input
  wire [ 2:0] cfg_interrupt_msi_function_number; // input


  IBUF sys_reset_n_ibuf (.O(sys_rst_n_c), .I(pcie_rst_n));

  // ref_clk IBUFDS from the edge connector
  IBUFDS_GTE2 refclk_ibuf (.O(sys_clk), .ODIV2(), .I(pcie_refclk_p), .CEB(1'b0), .IB(pcie_refclk_n));

  localparam PL_LINK_CAP_MAX_LINK_WIDTH = 8                ; // PCIe Lane Width
  localparam C_DATA_WIDTH               = 256              ; // AXI interface data width
  localparam KEEP_WIDTH                 = C_DATA_WIDTH / 32; // TSTRB width
  localparam PCIE_REFCLK_FREQ           = 0                ; // PCIe Reference Clock Frequency
  localparam PCIE_USERCLK1_FREQ         = 5                ; // PCIe Core Clock Frequency - Core Clock Freq
  localparam PCIE_USERCLK2_FREQ         = 4                ; // PCIe User Clock Frequency - User Clock Freq



// Support Level Wrapper
  pcie3_7x_0_support #(
    .PL_LINK_CAP_MAX_LINK_WIDTH(PL_LINK_CAP_MAX_LINK_WIDTH), // PCIe Lane Width
    .C_DATA_WIDTH              (C_DATA_WIDTH              ), //  AXI interface data width
    .KEEP_WIDTH                (KEEP_WIDTH                ), // TSTRB width
    .PCIE_REFCLK_FREQ          (PCIE_REFCLK_FREQ          ), // PCIe Reference Clock Frequency
    .PCIE_USERCLK1_FREQ        (PCIE_USERCLK1_FREQ        ), // PCIe Core Clock Frequency - Core Clock Freq
    .PCIE_USERCLK2_FREQ        (PCIE_USERCLK2_FREQ        )  // PCIe User Clock Frequency - User Clock Freq
  ) pcie3_7x_0_support_i (
    //---------------------------------------------------------------------------------------//
    //  PCI Express (pci_exp) Interface                                                      //
    //---------------------------------------------------------------------------------------//
    
    // Tx
    .pci_exp_txn                      (pcie_tx_n                         ),
    .pci_exp_txp                      (pcie_tx_p                         ),
    
    // Rx
    .pci_exp_rxn                      (pcie_rx_n                         ),
    .pci_exp_rxp                      (pcie_rx_p                         ),
    
    //---------------------------------------------------------------------------------------------------------------//
    // Clock & GT COMMON Sharing Interface                                                                        //
    //---------------------------------------------------------------------------------------------------------------//
    .pipe_pclk_out_slave              (                                  ),
    .pipe_rxusrclk_out                (                                  ),
    .pipe_rxoutclk_out                (                                  ),
    .pipe_dclk_out                    (                                  ),
    .pipe_userclk1_out                (                                  ),
    .pipe_oobclk_out                  (                                  ),
    .pipe_userclk2_out                (                                  ),
    .pipe_mmcm_lock_out               (                                  ),
    .pipe_pclk_sel_slave              ({PL_LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .pipe_mmcm_rst_n                  (pipe_mmcm_rst_n                   ),
    
    //---------------------------------------------------------------------------------------//
    //  AXI Interface                                                                        //
    //---------------------------------------------------------------------------------------//
    
    .user_clk                         (user_clk                          ), // output
    .user_reset                       (user_reset                        ), // output
    .user_lnk_up                      (user_lnk_up                       ), // output
    .user_app_rdy                     (user_app_rdy                      ), // output
    
    .s_axis_rq_tlast                  (s_axis_rq_tlast                   ), // input
    .s_axis_rq_tdata                  (s_axis_rq_tdata                   ), // input  [C_DATA_WIDTH-1:0]
    .s_axis_rq_tuser                  (s_axis_rq_tuser                   ), // input  [59:0]
    .s_axis_rq_tkeep                  (s_axis_rq_tkeep                   ), // input  [KEEP_WIDTH-1:0]
    .s_axis_rq_tready                 (s_axis_rq_tready_array            ), // output [3:0]
    .s_axis_rq_tvalid                 (s_axis_rq_tvalid                  ), // input
    
    .m_axis_rc_tdata                  (m_axis_rc_tdata                   ), // output  [C_DATA_WIDTH-1:0]
    .m_axis_rc_tuser                  (m_axis_rc_tuser                   ), // output  [74:0]
    .m_axis_rc_tlast                  (m_axis_rc_tlast                   ), // output
    .m_axis_rc_tkeep                  (m_axis_rc_tkeep                   ), // output  [KEEP_WIDTH-1:0]
    .m_axis_rc_tvalid                 (m_axis_rc_tvalid                  ), // output
    .m_axis_rc_tready                 (m_axis_rc_tready_array            ), // input   [21:0]
    
    .m_axis_cq_tdata                  (m_axis_cq_tdata                   ), // output  [C_DATA_WIDTH-1:0]
    .m_axis_cq_tuser                  (m_axis_cq_tuser                   ), // output  [84:0]
    .m_axis_cq_tlast                  (m_axis_cq_tlast                   ), // output
    .m_axis_cq_tkeep                  (m_axis_cq_tkeep                   ), // output  [KEEP_WIDTH-1:0]
    .m_axis_cq_tvalid                 (m_axis_cq_tvalid                  ), // output
    .m_axis_cq_tready                 (m_axis_cq_tready_array            ), // input   [21:0]
    
    .s_axis_cc_tdata                  (s_axis_cc_tdata                   ), // input  [C_DATA_WIDTH-1:0]
    .s_axis_cc_tuser                  (s_axis_cc_tuser                   ), // input  [32:0]
    .s_axis_cc_tlast                  (s_axis_cc_tlast                   ), // input
    .s_axis_cc_tkeep                  (s_axis_cc_tkeep                   ), // input  [KEEP_WIDTH-1:0]
    .s_axis_cc_tvalid                 (s_axis_cc_tvalid                  ), // input
    .s_axis_cc_tready                 (s_axis_cc_tready_array            ), // output  [3:0]
    
    //--------------------------------------------------------------------------
    //  Configuration (CFG) Interface
    //--------------------------------------------------------------------------
    
    .pcie_tfc_nph_av                  (pcie_tfc_nph_av                   ), // output  [1:0]
    .pcie_tfc_npd_av                  (pcie_tfc_npd_av                   ), // output  [1:0]
    .pcie_rq_seq_num                  (pcie_rq_seq_num                   ), // output  [3:0]
    .pcie_rq_seq_num_vld              (pcie_rq_seq_num_vld               ), // output
    .pcie_rq_tag                      (pcie_rq_tag                       ), // output  [5:0]
    .pcie_rq_tag_vld                  (pcie_rq_tag_vld                   ), // output
    
    .pcie_cq_np_req                   (pcie_cq_np_req                    ), // input
    .pcie_cq_np_req_count             (pcie_cq_np_req_count              ), // output  [5:0]
    
    .cfg_phy_link_down                (cfg_phy_link_down                 ), // output
    .cfg_phy_link_status              (                                  ), // output  [1:0]
    .cfg_negotiated_width             (cfg_negotiated_width              ), // output  [3:0]
    .cfg_current_speed                (cfg_current_speed                 ), // output  [2:0]
    .cfg_max_payload                  (cfg_max_payload                   ), // output  [2:0]
    .cfg_max_read_req                 (cfg_max_read_req                  ), // output  [2:0]
    .cfg_function_status              (cfg_function_status               ), // output  [7:0]
    .cfg_function_power_state         (cfg_function_power_state          ), // output  [5:0]
    .cfg_vf_status                    (cfg_vf_status                     ), // output  [11:0]
    .cfg_vf_power_state               (cfg_vf_power_state                ), // output  [17:0]
    .cfg_link_power_state             (cfg_link_power_state              ), // output  [1:0]
    
    // Error Reporting Interface                                                // Error Reporting Interface
    .cfg_err_cor_out                  (cfg_err_cor_out                   ), // output
    .cfg_err_nonfatal_out             (cfg_err_nonfatal_out              ), // output
    .cfg_err_fatal_out                (cfg_err_fatal_out                 ), // output
    
    .cfg_ltr_enable                   (cfg_ltr_enable                    ), // output
    .cfg_ltssm_state                  (cfg_ltssm_state                   ), // output  [5:0]
    .cfg_rcb_status                   (cfg_rcb_status                    ), // output  [1:0]
    .cfg_dpa_substate_change          (cfg_dpa_substate_change           ), // output  [1:0]
    .cfg_obff_enable                  (cfg_obff_enable                   ), // output  [1:0]
    .cfg_pl_status_change             (cfg_pl_status_change              ), // output
    
    .cfg_tph_requester_enable         (cfg_tph_requester_enable          ), // output  [1:0]
    .cfg_tph_st_mode                  (cfg_tph_st_mode                   ), // output  [5:0]
    .cfg_vf_tph_requester_enable      (cfg_vf_tph_requester_enable       ), // output  [5:0]
    .cfg_vf_tph_st_mode               (cfg_vf_tph_st_mode                ), // output  [17:0]
    
    // Management Interface                                                     // Management Interface
    .cfg_mgmt_addr                    (cfg_mgmt_addr                     ), // input  [18:0]
    .cfg_mgmt_write                   (cfg_mgmt_write                    ), // input
    .cfg_mgmt_write_data              (cfg_mgmt_write_data               ), // input  [31:0]
    .cfg_mgmt_byte_enable             (cfg_mgmt_byte_enable              ), // input  [3:0]
    .cfg_mgmt_read                    (cfg_mgmt_read                     ), // input
    .cfg_mgmt_read_data               (cfg_mgmt_read_data                ), // output  [31:0]
    .cfg_mgmt_read_write_done         (cfg_mgmt_read_write_done          ), // output
    .cfg_mgmt_type1_cfg_reg_access    (cfg_mgmt_type1_cfg_reg_access     ), // input
    .cfg_msg_received                 (cfg_msg_received                  ), // output
    .cfg_msg_received_data            (cfg_msg_received_data             ), // output  [7:0]
    .cfg_msg_received_type            (cfg_msg_received_type             ), // output  [4:0]
    .cfg_msg_transmit                 (cfg_msg_transmit                  ), // input
    .cfg_msg_transmit_type            (cfg_msg_transmit_type             ), // input   [2:0]
    .cfg_msg_transmit_data            (cfg_msg_transmit_data             ), // input   [31:0]
    .cfg_msg_transmit_done            (cfg_msg_transmit_done             ), // output
    .cfg_fc_ph                        (cfg_fc_ph                         ), // output  [7:0]
    .cfg_fc_pd                        (cfg_fc_pd                         ), // output  [11:0]
    .cfg_fc_nph                       (cfg_fc_nph                        ), // output  [7:0]
    .cfg_fc_npd                       (cfg_fc_npd                        ), // output  [11:0]
    .cfg_fc_cplh                      (cfg_fc_cplh                       ), // output  [7:0]
    .cfg_fc_cpld                      (cfg_fc_cpld                       ), // output  [11:0]
    .cfg_fc_sel                       (cfg_fc_sel                        ), // input   [2:0]
    .cfg_per_func_status_control      (cfg_per_func_status_control       ), // input   [2:0]
    .cfg_per_func_status_data         (cfg_per_func_status_data          ), // output  [15:0]
    .cfg_subsys_vend_id               (cfg_subsys_vend_id                ), // input   [15:0]
    .cfg_hot_reset_out                (cfg_hot_reset_out                 ), // output
    .cfg_config_space_enable          (cfg_config_space_enable           ), // input
    .cfg_req_pm_transition_l23_ready  (cfg_req_pm_transition_l23_ready   ), // input
    .cfg_hot_reset_in                 (cfg_hot_reset_in                  ), // input
    .cfg_ds_port_number               (cfg_ds_port_number                ), // input   [7:0]
    .cfg_ds_bus_number                (cfg_ds_bus_number                 ), // input   [7:0]
    .cfg_ds_device_number             (cfg_ds_device_number              ), // input   [4:0]
    .cfg_ds_function_number           (cfg_ds_function_number            ), // input   [2:0]
    .cfg_per_function_number          (cfg_per_function_number           ), // input   [2:0]
    .cfg_per_function_output_request  (cfg_per_function_output_request   ), // input
    .cfg_per_function_update_done     (cfg_per_function_update_done      ), // output
    .cfg_dsn                          (cfg_dsn                           ), // input   [63:0]
    .cfg_power_state_change_interrupt (cfg_power_state_change_interrupt  ), // output
    .cfg_power_state_change_ack       (cfg_power_state_change_ack        ), // input
    .cfg_err_cor_in                   (cfg_err_cor_in                    ), // input
    .cfg_err_uncor_in                 (cfg_err_uncor_in                  ), // input
    .cfg_flr_in_process               (cfg_flr_in_process                ), // output  [1:0]
    .cfg_flr_done                     (cfg_flr_done                      ), // input   [1:0]
    .cfg_vf_flr_in_process            (cfg_vf_flr_in_process             ), // output  [5:0]
    .cfg_vf_flr_done                  (cfg_vf_flr_done                   ), // input   [5:0]
    .cfg_link_training_enable         (cfg_link_training_enable          ), // input
    .cfg_ext_read_received            (cfg_ext_read_received             ), // output
    .cfg_ext_write_received           (cfg_ext_write_received            ), // output
    .cfg_ext_register_number          (cfg_ext_register_number           ), // output  [9:0]
    .cfg_ext_function_number          (cfg_ext_function_number           ), // output  [7:0]
    .cfg_ext_write_data               (cfg_ext_write_data                ), // output  [31:0]
    .cfg_ext_write_byte_enable        (cfg_ext_write_byte_enable         ), // output  [3:0]
    .cfg_ext_read_data                (cfg_ext_read_data                 ), // input   [31:0]
    .cfg_ext_read_data_valid          (cfg_ext_read_data_valid           ), // input
    //--------------------------------------------------------------------------
    // EP Only
    //--------------------------------------------------------------------------
    
    // Interrupt Interface Signals
    .cfg_interrupt_int                (cfg_interrupt_int                 ), // input   [3:0]
    .cfg_interrupt_pending            (cfg_interrupt_pending             ), // input   [1:0]
    .cfg_interrupt_sent               (cfg_interrupt_sent                ), // output
    .cfg_interrupt_msi_enable         (cfg_interrupt_msi_enable          ), // output  [1:0]
    .cfg_interrupt_msi_vf_enable      (cfg_interrupt_msi_vf_enable       ), // output  [5:0]
    .cfg_interrupt_msi_mmenable       (cfg_interrupt_msi_mmenable        ), // output  [5:0]
    .cfg_interrupt_msi_mask_update    (cfg_interrupt_msi_mask_update     ), // output
    .cfg_interrupt_msi_data           (cfg_interrupt_msi_data            ), // output  [31:0]
    .cfg_interrupt_msi_select         (cfg_interrupt_msi_select          ), // input   [3:0]
    .cfg_interrupt_msi_int            (cfg_interrupt_msi_int             ), // input   [31:0]
    .cfg_interrupt_msi_pending_status (cfg_interrupt_msi_pending_status  ), // input   [63:0]
    .cfg_interrupt_msi_sent           (cfg_interrupt_msi_sent            ), // output
    .cfg_interrupt_msi_fail           (cfg_interrupt_msi_fail            ), // output
    .cfg_interrupt_msi_attr           (cfg_interrupt_msi_attr            ), // input   [2:0]
    .cfg_interrupt_msi_tph_present    (cfg_interrupt_msi_tph_present     ), // input
    .cfg_interrupt_msi_tph_type       (cfg_interrupt_msi_tph_type        ), // input   [1:0]
    .cfg_interrupt_msi_tph_st_tag     (cfg_interrupt_msi_tph_st_tag      ), // input   [8:0]
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number ), // input   [2:0]
    .cfg_interrupt_msix_enable        (cfg_interrupt_msix_enable         ), // output  [1:0]
    .cfg_interrupt_msix_mask          (cfg_interrupt_msix_mask           ), // output  [1:0]
    .cfg_interrupt_msix_vf_enable     (cfg_interrupt_msix_vf_enable      ), // output  [5:0]
    .cfg_interrupt_msix_vf_mask       (cfg_interrupt_msix_vf_mask        ), // output  [5:0]
    .cfg_interrupt_msix_data          (cfg_interrupt_msix_data           ), // input   [31:0]
    .cfg_interrupt_msix_address       (cfg_interrupt_msix_address        ), // input   [63:0]
    .cfg_interrupt_msix_int           (cfg_interrupt_msix_int            ), // input
    .cfg_interrupt_msix_sent          (cfg_interrupt_msix_sent           ), // output
    .cfg_interrupt_msix_fail          (cfg_interrupt_msix_fail           ), // output
    
    //----------------------------------------------------------------------------//
    //  System(SYS) Interface                                                     //
    //----------------------------------------------------------------------------//
    .sys_clk                          (sys_clk                           ),
    .sys_reset                        (~sys_rst_n_c                      )
  );


  assign s_axis_rq_tready = s_axis_rq_tready_array[0];
  assign s_axis_cc_tready = s_axis_cc_tready_array[0];
  `ifndef VERSION_VIVADO_2014_4
    assign m_axis_cq_tready_array = m_axis_cq_tready;
    assign m_axis_rc_tready_array = m_axis_rc_tready;
  `else
    assign m_axis_cq_tready_array = {22{m_axis_cq_tready}};
    assign m_axis_rc_tready_array = {22{m_axis_rc_tready}};
  `endif
  assign pcie_cq_np_req = 1'b1;

  //--------------------------------------------------------------------------------------------------------------------//
  // CFG_WRITE : Description : Write Configuration Space MI decode error, Disabling LFSR update from SKP. CR#
  //--------------------------------------------------------------------------------------------------------------------//
  reg write_cfg_done_1;

  always @(posedge user_clk) begin : cfg_write_skp_nolfsr
    if (user_reset) begin
      cfg_mgmt_addr        <= #TCQ 32'b0;
      cfg_mgmt_write_data  <= #TCQ 32'b0;
      cfg_mgmt_byte_enable <= #TCQ 4'b0;
      cfg_mgmt_write       <= #TCQ 1'b0;
      cfg_mgmt_read        <= #TCQ 1'b0;
      write_cfg_done_1     <= #TCQ 1'b0;
    end else begin
      if (cfg_mgmt_read_write_done == 1'b1 && write_cfg_done_1 == 1'b1) begin
        cfg_mgmt_addr        <= #TCQ 0;
        cfg_mgmt_write_data  <= #TCQ 0;
        cfg_mgmt_byte_enable <= #TCQ 0;
        cfg_mgmt_write       <= #TCQ 0;
        cfg_mgmt_read        <= #TCQ 0;
      end else if (cfg_mgmt_read_write_done == 1'b1 && write_cfg_done_1 == 1'b0) begin
        cfg_mgmt_addr              <= #TCQ 32'h40082;
        cfg_mgmt_write_data[31:28] <= #TCQ cfg_mgmt_read_data[31:28];
        cfg_mgmt_write_data[27]    <= #TCQ 1'b1;
        cfg_mgmt_write_data[26:0]  <= #TCQ cfg_mgmt_read_data[26:0];
        cfg_mgmt_byte_enable       <= #TCQ 4'hF;
        cfg_mgmt_write             <= #TCQ 1'b1;
        cfg_mgmt_read              <= #TCQ 1'b0;
        write_cfg_done_1           <= #TCQ 1'b1;
      end else if (write_cfg_done_1 == 1'b0) begin
        cfg_mgmt_addr        <= #TCQ 32'h40082;
        cfg_mgmt_write_data  <= #TCQ 32'b0;
        cfg_mgmt_byte_enable <= #TCQ 4'hF;
        cfg_mgmt_write       <= #TCQ 1'b0;
        cfg_mgmt_read        <= #TCQ 1'b1;
      end
    end
  end



  assign cfg_mgmt_type1_cfg_reg_access   = 1'b0;
  assign cfg_msg_transmit                = 1'b0;
  assign cfg_msg_transmit_type           = 3'b0; //  [2:0]
  assign cfg_msg_transmit_data           = 32'b0; // [31:0]
  assign cfg_fc_sel                      = 3'b0; // [2:0]
  assign cfg_per_func_status_control     = 3'h0;
  assign cfg_subsys_vend_id              = 16'h10EE;
  assign cfg_config_space_enable         = 1'b1;
  assign cfg_req_pm_transition_l23_ready = 1'b0;
  assign cfg_hot_reset_in                = 1'b0;
  assign cfg_ds_port_number              = 8'h0;
  assign cfg_ds_bus_number               = 8'h0;
  assign cfg_ds_device_number            = 5'h0;
  assign cfg_ds_function_number          = 3'h0;
  assign cfg_per_function_number         = 3'h0;                 // Zero out function num for status req
  assign cfg_per_function_output_request = 1'b0;                 // Do not request configuration status update
  assign cfg_dsn                         = {`PCI_EXP_EP_DSN_2, `PCI_EXP_EP_DSN_1};  // Assign the input DSN
  assign cfg_err_cor_in                  = 1'b0;                 // Never report Correctable Error
  assign cfg_err_uncor_in                = 1'b0;                 // Never report UnCorrectable Error
  assign cfg_link_training_enable        = 1'b1;                 // Always enable LTSSM to bring up the Link
  assign cfg_ext_read_data               = 32'h0;                // Do not provide cfg data externally
  assign cfg_ext_read_data_valid         = 1'b0;                 // Disable external implemented reg cfg read


  reg trn_pending;

  wire req_compl ;
  wire compl_done;
  assign req_compl  = 1'b0;
  assign compl_done = 1'b1;

  //  Check if completion is pending
  always @ (posedge user_clk)
    begin
      if (user_reset ) begin
        trn_pending <= #TCQ 1'b0;
      end else begin
        if (!trn_pending && req_compl)
          trn_pending <= #TCQ 1'b1;
        else if (compl_done)
          trn_pending <= #TCQ 1'b0;
      end
    end

  //  Turn-off OK if requested and no transaction is pending
  always @ (posedge user_clk)
    begin
      if (user_reset ) begin
        cfg_power_state_change_ack <= 1'b0;
      end else begin
        if ( cfg_power_state_change_interrupt  && !trn_pending)
          cfg_power_state_change_ack <= 1'b1;
        else
          cfg_power_state_change_ack <= 1'b0;
      end
    end

  reg [1:0] cfg_flr_done_reg0   ;
  reg [5:0] cfg_vf_flr_done_reg0;
  reg [1:0] cfg_flr_done_reg1   ;
  reg [5:0] cfg_vf_flr_done_reg1;

  always @(posedge user_clk) begin
    if (user_reset) begin
      cfg_flr_done_reg0    <= 2'b0;
      cfg_vf_flr_done_reg0 <= 6'b0;
      cfg_flr_done_reg1    <= 2'b0;
      cfg_vf_flr_done_reg1 <= 6'b0;
    end else begin
      cfg_flr_done_reg0    <= cfg_flr_in_process;
      cfg_vf_flr_done_reg0 <= cfg_vf_flr_in_process;
      cfg_flr_done_reg1    <= cfg_flr_done_reg0;
      cfg_vf_flr_done_reg1 <= cfg_vf_flr_done_reg0;
    end
  end

  assign cfg_flr_done[0]    = ~cfg_flr_done_reg1[0] && cfg_flr_done_reg0[0]; assign cfg_flr_done[1] = ~cfg_flr_done_reg1[1] && cfg_flr_done_reg0[1];
  assign cfg_vf_flr_done[0] = ~cfg_vf_flr_done_reg1[0] && cfg_vf_flr_done_reg0[0]; assign cfg_vf_flr_done[1] = ~cfg_vf_flr_done_reg1[1] && cfg_vf_flr_done_reg0[1]; assign cfg_vf_flr_done[2] = ~cfg_vf_flr_done_reg1[2] && cfg_vf_flr_done_reg0[2]; assign cfg_vf_flr_done[3] = ~cfg_vf_flr_done_reg1[3] && cfg_vf_flr_done_reg0[3]; assign cfg_vf_flr_done[4] = ~cfg_vf_flr_done_reg1[4] && cfg_vf_flr_done_reg0[4]; assign cfg_vf_flr_done[5] = ~cfg_vf_flr_done_reg1[5] && cfg_vf_flr_done_reg0[5];






  // Do not request per function status

  assign cfg_interrupt_int                 = 4'b0; // [3:0]
  assign cfg_interrupt_msi_int             = 32'b0; // [31:0]
  assign cfg_interrupt_pending             = 2'h0;
  assign cfg_interrupt_msi_select          = 4'h0;
  assign cfg_interrupt_msi_pending_status  = 64'h0;
  assign cfg_interrupt_msi_attr            = 3'h0;
  assign cfg_interrupt_msi_tph_present     = 1'b0;
  assign cfg_interrupt_msi_tph_type        = 2'h0;
  assign cfg_interrupt_msi_tph_st_tag      = 9'h0;
  assign cfg_interrupt_msi_function_number = 3'h0;





endmodule






