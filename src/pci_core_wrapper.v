module pcie_core_wrapper (

  // PERST - active-low reset
  input                                                 pcie_perst                                      ,

  // Reference clock - 100MHz
  input                                                 pcie_clk_n                                      ,
  input                                                 pcie_clk_p                                      ,

  // Rx/Tx IF x8 lanes
  input  [  7:0]                                        pcie_rx_p                                       ,
  input  [  7:0]                                        pcie_rx_n                                       ,
  output [  7:0]                                        pcie_tx_p                                       ,
  output [  7:0]                                        pcie_tx_n                                       ,

  //  user control
  output                                                pcie_user_clk                                   ,
  output                                                pcie_user_reset                                 ,
  // Completer Request (RQ)
  output                                                pcie_creq_tvalid                                ,
  input                                                 pcie_creq_tready                                ,
  output [511:0]                                        pcie_creq_tdata                                 ,
  output [ 15:0]                                        pcie_creq_tkeep                                 ,
  output                                                pcie_creq_tlast                                 ,
  output [182:0]                                        pcie_creq_tuser                                 ,
  output [  5:0]                                        pcie_cq_np_req_count                            ,
  input  [  1:0]                                        pcie_cq_np_req                                  ,
  // Completer Response (CC)
  input                                                 pcie_cres_tvalid                                ,
  output                                                pcie_cres_tready                                ,
  input  [511:0]                                        pcie_cres_tdata                                 ,
  input  [ 15:0]                                        pcie_cres_tkeep                                 ,
  input                                                 pcie_cres_tlast                                 ,
  input  [ 80:0]                                        pcie_cres_tuser                                 ,
  // Requester Request (RQ)
  input                                                 pcie_rreq_tvalid                                ,
  output                                                pcie_rreq_tready                                ,
  input  [511:0]                                        pcie_rreq_tdata                                 ,
  input  [ 15:0]                                        pcie_rreq_tkeep                                 ,
  input                                                 pcie_rreq_tlast                                 ,
  input  [136:0]                                        pcie_rreq_tuser                                 ,
  // Requester Response (RC)
  output [511:0]                                        pcie_rres_tdata                                 ,
  output [ 15:0]                                        pcie_rres_tkeep                                 ,
  output                                                pcie_rres_tlast                                 ,
  input                                                 pcie_rres_tready                                ,
  output                                                pcie_rres_tvalid                                ,
  output [160:0]                                        pcie_rres_tuser                                 ,
  // max payload size
  output [  1:0]                                        cfg_max_payload
);

  //  Completer Response Interface
  wire   [  3:0]                                        pcie_cres_tready_i                              ;
  //  Requester Request Interface
  wire   [  3:0]                                        pcie_rreq_tready_i                              ;
  wire                                                  pcie_rq_tag_vld0                                ;
  wire                                                  pcie_rq_tag_vld1                                ;
  wire   [  7:0]                                        pcie_rq_tag0                                    ;
  wire   [  7:0]                                        pcie_rq_tag1                                    ;
  wire   [  5:0]                                        pcie_rq_seq_num0                                ;
  wire   [  5:0]                                        pcie_rq_seq_num1                                ;
  wire                                                  pcie_rq_seq_num_vld0                            ;
  wire                                                  pcie_rq_seq_num_vld1                            ;
  //  Power Management Interface
  wire                                                  cfg_pm_aspm_l1_entry_reject                     ;
  wire                                                  cfg_pm_aspm_tx_l0s_entry_disable                ;
  //  Configuration Management Interface
  wire   [  9:0]                                        cfg_mgmt_addr                                   ;
  wire   [  7:0]                                        cfg_mgmt_function_number                        ;
  wire                                                  cfg_mgmt_write                                  ;
  wire   [ 31:0]                                        cfg_mgmt_write_data                             ;
  wire   [  3:0]                                        cfg_mgmt_byte_enable                            ;
  wire                                                  cfg_mgmt_read                                   ;
  wire   [ 31:0]                                        cfg_mgmt_read_data                              ;
  wire                                                  cfg_mgmt_read_write_done                        ;
  wire                                                  cfg_mgmt_debug_access                           ;
  //  Configuration Status Interface
  wire                                                  cfg_phy_link_down                               ;
  wire   [  1:0]                                        cfg_phy_link_status                             ;
  wire   [  2:0]                                        cfg_negotiated_width                            ;
  wire   [  1:0]                                        cfg_current_speed                               ;
  wire   [  2:0]                                        cfg_max_read_req                                ;
  wire   [ 15:0]                                        cfg_function_status                             ;
  wire   [503:0]                                        cfg_vf_status                                   ;
  wire   [ 11:0]                                        cfg_function_power_state                        ;
  wire   [755:0]                                        cfg_vf_power_state                              ;
  wire   [  1:0]                                        cfg_link_power_state                            ;
  wire   [  4:0]                                        cfg_local_error_out                             ;
  wire                                                  cfg_local_error_valid                           ;
  wire   [  1:0]                                        cfg_rx_pm_state                                 ;
  wire   [  1:0]                                        cfg_tx_pm_state                                 ;
  wire   [  5:0]                                        cfg_ltssm_state                                 ;
  wire   [  3:0]                                        cfg_rcb_status                                  ;
  wire   [  1:0]                                        cfg_obff_enable                                 ;
  wire                                                  cfg_pl_status_change                            ;
  wire   [  3:0]                                        cfg_tph_requester_enable                        ;
  wire   [ 11:0]                                        cfg_tph_st_mode                                 ;
  wire   [251:0]                                        cfg_vf_tph_requester_enable                     ;
  wire   [755:0]                                        cfg_vf_tph_st_mode                              ;
  wire   [  3:0]                                        pcie_tfc_nph_av                                 ;
  wire   [  3:0]                                        pcie_tfc_npd_av                                 ;
  wire   [  3:0]                                        pcie_rq_tag_av                                  ;
  //  Configuration Received Message Interface
  wire                                                  cfg_msg_received                                ;
  wire   [  7:0]                                        cfg_msg_received_data                           ;
  wire   [  4:0]                                        cfg_msg_received_type                           ;
  //  Configuration Transmit Message Interface
  wire                                                  cfg_msg_transmit                                ;
  wire   [  2:0]                                        cfg_msg_transmit_type                           ;
  wire   [ 31:0]                                        cfg_msg_transmit_data                           ;
  wire                                                  cfg_msg_transmit_done                           ;
  //  Configuration Flow Control Interface
  wire   [  7:0]                                        cfg_fc_ph                                       ;
  wire   [ 11:0]                                        cfg_fc_pd                                       ;
  wire   [  7:0]                                        cfg_fc_nph                                      ;
  wire   [ 11:0]                                        cfg_fc_npd                                      ;
  wire   [  7:0]                                        cfg_fc_cplh                                     ;
  wire   [ 11:0]                                        cfg_fc_cpld                                     ;
  wire   [  2:0]                                        cfg_fc_sel                                      ;
  //  Configuration Control Interface
  wire                                                  cfg_hot_reset_in                                ;
  wire                                                  cfg_hot_reset_out                               ;
  wire                                                  cfg_config_space_enable                         ;
  wire   [ 63:0]                                        cfg_dsn                                         ;
  wire   [  7:0]                                        cfg_ds_bus_number                               ;
  wire   [  4:0]                                        cfg_ds_device_number                            ;
  wire                                                  cfg_power_state_change_ack                      ;
  wire                                                  cfg_power_state_change_interrupt                ;
  wire   [  7:0]                                        cfg_ds_port_number                              ;
  wire                                                  cfg_err_cor_in                                  ;
  wire                                                  cfg_err_cor_out                                 ;
  wire                                                  cfg_err_fatal_out                               ;
  wire                                                  cfg_err_nonfatal_out                            ;
  wire                                                  cfg_err_uncor_in                                ;
  wire   [  3:0]                                        cfg_flr_done                                    ;
  wire                                                  cfg_vf_flr_done                                 ;
  wire   [  7:0]                                        cfg_vf_flr_func_num                             ;
  wire   [  3:0]                                        cfg_flr_in_process                              ;
  wire   [251:0]                                        cfg_vf_flr_in_process                           ;
  wire                                                  cfg_req_pm_transition_l23_ready                 ;
  wire                                                  cfg_link_training_enable                        ;
  wire   [  7:0]                                        cfg_bus_number                                  ;
  //  Configuration Interrupt Controller Interface
  wire   [  3:0]                                        cfg_interrupt_int                               ;
  wire                                                  cfg_interrupt_sent                              ;
  wire   [  3:0]                                        cfg_interrupt_pending                           ;
  //  MSI Interrupt Interface
  wire   [  3:0]                                        cfg_interrupt_msi_enable                        ;
  wire   [ 31:0]                                        cfg_interrupt_msi_int                           ;
  wire   [  7:0]                                        cfg_interrupt_msi_function_number               ;
  wire                                                  cfg_interrupt_msi_sent                          ;
  wire                                                  cfg_interrupt_msi_fail                          ;
  wire   [ 11:0]                                        cfg_interrupt_msi_mmenable                      ;
  wire   [ 31:0]                                        cfg_interrupt_msi_pending_status                ;
  wire   [  1:0]                                        cfg_interrupt_msi_pending_status_function_num   ;
  wire                                                  cfg_interrupt_msi_pending_status_data_enable    ;
  wire                                                  cfg_interrupt_msi_mask_update                   ;
  wire   [  1:0]                                        cfg_interrupt_msi_select                        ;
  wire   [ 31:0]                                        cfg_interrupt_msi_data                          ;
  wire   [  2:0]                                        cfg_interrupt_msi_attr                          ;
  wire                                                  cfg_interrupt_msi_tph_present                   ;
  wire   [  1:0]                                        cfg_interrupt_msi_tph_type                      ;
  wire   [  7:0]                                        cfg_interrupt_msi_tph_st_tag                    ;
  wire                                                  pcie_phy_rdy_out                                ;
  wire                                                  pcie_user_lnk_up                                ;
  //  Configuration Extend Interface
  wire                                                  cfg_ext_read_received                           ;
  wire                                                  cfg_ext_write_received                          ;
  wire   [  9:0]                                        cfg_ext_register_number                         ;
  wire   [  7:0]                                        cfg_ext_function_number                         ;
  wire   [ 31:0]                                        cfg_ext_write_data                              ;
  wire   [  3:0]                                        cfg_ext_write_byte_enable                       ;
  wire   [ 31:0]                                        cfg_ext_read_data                               ;
  wire                                                  cfg_ext_read_data_valid                         ;
  //  Clock and Reset Interface
  wire                                                  pcie_reset                                      ;
  wire                                                  pcie_clk                                        ;

  // Rx/Tx IF x8 lanes (UnConnected)
  wire   [  7:0]                                        pcie_tx_n_unc                                   ;
  wire   [  7:0]                                        pcie_tx_p_unc                                   ;

  IBUF
  pcie_perst_ibuf
  (
    .O                                                ( pcie_reset                                     ),
    .I                                                ( pcie_perst                                     )
  );

  IBUFDS_GTE4
  pcie_clk_ibuf
  (
    .O                                                ( pcie_clk_gt                                    ),
    .ODIV2                                            ( pcie_clk                                       ),
    .I                                                ( pcie_clk_p                                     ),
    .CEB                                              ( 1'b0                                           ),
    .IB                                               ( pcie_clk_n                                     )
  );

  //Xilinx PCIe IP
  xilinx_pcie4 xilinx_pcie4
  (
    .pci_exp_txn                                      ( {pcie_tx_n_unc,pcie_tx_n}                      ),
    .pci_exp_txp                                      ( {pcie_tx_p_unc,pcie_tx_p}                      ),
    .pci_exp_rxn                                      ( {8'hFF,pcie_rx_n}                              ),
    .pci_exp_rxp                                      ( {8'h00,pcie_rx_p}                              ),
    //  Clock and Reset Interface
    .sys_clk                                          ( pcie_clk                                       ),
    .sys_clk_gt                                       ( pcie_clk_gt                                    ),
    .sys_reset                                        ( pcie_reset                                     ),
    .user_clk                                         ( pcie_user_clk                                  ),
    .user_reset                                       ( pcie_user_reset                                ),
    .phy_rdy_out                                      ( pcie_phy_rdy_out                               ),
    .user_lnk_up                                      ( pcie_user_lnk_up                               ),
    //  Completer Request Interface
    .m_axis_cq_tdata                                  ( pcie_creq_tdata                                ),
    .m_axis_cq_tuser                                  ( pcie_creq_tuser                                ),
    .m_axis_cq_tlast                                  ( pcie_creq_tlast                                ),
    .m_axis_cq_tkeep                                  ( pcie_creq_tkeep                                ),
    .m_axis_cq_tvalid                                 ( pcie_creq_tvalid                               ),
    .m_axis_cq_tready                                 ( pcie_creq_tready                               ),
    .pcie_cq_np_req                                   ( pcie_cq_np_req                                 ),
    .pcie_cq_np_req_count                             ( pcie_cq_np_req_count                           ),
    //  Completer Completion Interface
    .s_axis_cc_tdata                                  ( pcie_cres_tdata                                ),
    .s_axis_cc_tuser                                  ( pcie_cres_tuser                                ),
    .s_axis_cc_tlast                                  ( pcie_cres_tlast                                ),
    .s_axis_cc_tkeep                                  ( pcie_cres_tkeep                                ),
    .s_axis_cc_tvalid                                 ( pcie_cres_tvalid                               ),
    .s_axis_cc_tready                                 ( pcie_cres_tready_i                             ),
    //  Requester Request Interface
    .s_axis_rq_tdata                                  ( pcie_rreq_tdata                                ),
    .s_axis_rq_tuser                                  ( pcie_rreq_tuser                                ),
    .s_axis_rq_tlast                                  ( pcie_rreq_tlast                                ),
    .s_axis_rq_tkeep                                  ( pcie_rreq_tkeep                                ),
    .s_axis_rq_tvalid                                 ( pcie_rreq_tvalid                               ),
    .s_axis_rq_tready                                 ( pcie_rreq_tready_i                             ),
    .pcie_rq_seq_num0                                 ( pcie_rq_seq_num0                               ),
    .pcie_rq_seq_num_vld0                             ( pcie_rq_seq_num_vld0                           ),
    .pcie_rq_tag0                                     ( pcie_rq_tag0                                   ),
    .pcie_rq_tag1                                     ( pcie_rq_tag1                                   ),
    .pcie_rq_tag_vld0                                 ( pcie_rq_tag_vld0                               ),
    .pcie_rq_tag_vld1                                 ( pcie_rq_tag_vld1                               ),
    .pcie_rq_seq_num1                                 ( pcie_rq_seq_num1                               ),
    .pcie_rq_seq_num_vld1                             ( pcie_rq_seq_num_vld1                           ),
    //  Requester Completion Interface
    .m_axis_rc_tdata                                  ( pcie_rres_tdata                                ),
    .m_axis_rc_tuser                                  ( pcie_rres_tuser                                ),
    .m_axis_rc_tlast                                  ( pcie_rres_tlast                                ),
    .m_axis_rc_tkeep                                  ( pcie_rres_tkeep                                ),
    .m_axis_rc_tvalid                                 ( pcie_rres_tvalid                               ),
    .m_axis_rc_tready                                 ( pcie_rres_tready                               ),
    //  Power Management Interface
    .cfg_pm_aspm_l1_entry_reject                      ( cfg_pm_aspm_l1_entry_reject                    ),
    .cfg_pm_aspm_tx_l0s_entry_disable                 ( cfg_pm_aspm_tx_l0s_entry_disable               ),
    //  Configuration Management Interface
    .cfg_mgmt_addr                                    ( cfg_mgmt_addr                                  ),
    .cfg_mgmt_function_number                         ( cfg_mgmt_function_number                       ),
    .cfg_mgmt_write                                   ( cfg_mgmt_write                                 ),
    .cfg_mgmt_write_data                              ( cfg_mgmt_write_data                            ),
    .cfg_mgmt_byte_enable                             ( cfg_mgmt_byte_enable                           ),
    .cfg_mgmt_read                                    ( cfg_mgmt_read                                  ),
    .cfg_mgmt_read_data                               ( cfg_mgmt_read_data                             ),
    .cfg_mgmt_read_write_done                         ( cfg_mgmt_read_write_done                       ),
    .cfg_mgmt_debug_access                            ( cfg_mgmt_debug_access                          ),
    //  Configuration Status Interface
    .cfg_phy_link_down                                ( cfg_phy_link_down                              ),
    .cfg_phy_link_status                              ( cfg_phy_link_status                            ),
    .cfg_negotiated_width                             ( cfg_negotiated_width                           ),
    .cfg_current_speed                                ( cfg_current_speed                              ),
    .cfg_max_payload                                  ( cfg_max_payload                                ),
    .cfg_max_read_req                                 ( cfg_max_read_req                               ),
    .cfg_function_status                              ( cfg_function_status                            ),
    .cfg_vf_status                                    ( cfg_vf_status                                  ),
    .cfg_function_power_state                         ( cfg_function_power_state                       ),
    .cfg_vf_power_state                               ( cfg_vf_power_state                             ),
    .cfg_link_power_state                             ( cfg_link_power_state                           ),
    .cfg_local_error_out                              ( cfg_local_error_out                            ),
    .cfg_local_error_valid                            ( cfg_local_error_valid                          ),
    .cfg_rx_pm_state                                  ( cfg_rx_pm_state                                ),
    .cfg_tx_pm_state                                  ( cfg_tx_pm_state                                ),
    .cfg_ltssm_state                                  ( cfg_ltssm_state                                ),
    .cfg_rcb_status                                   ( cfg_rcb_status                                 ),
    .cfg_obff_enable                                  ( cfg_obff_enable                                ),
    .cfg_pl_status_change                             ( cfg_pl_status_change                           ),
    .cfg_tph_requester_enable                         ( cfg_tph_requester_enable                       ),
    .cfg_tph_st_mode                                  ( cfg_tph_st_mode                                ),
    .cfg_vf_tph_requester_enable                      ( cfg_vf_tph_requester_enable                    ),
    .cfg_vf_tph_st_mode                               ( cfg_vf_tph_st_mode                             ),
    .pcie_tfc_nph_av                                  ( pcie_tfc_nph_av                                ),
    .pcie_tfc_npd_av                                  ( pcie_tfc_npd_av                                ),
    .pcie_rq_tag_av                                   ( pcie_rq_tag_av                                 ),
    //  Configuration Received Message Interface
    .cfg_msg_received                                 ( cfg_msg_received                               ),
    .cfg_msg_received_data                            ( cfg_msg_received_data                          ),
    .cfg_msg_received_type                            ( cfg_msg_received_type                          ),
    //  Configuration Transmit Message Interface
    .cfg_msg_transmit                                 ( cfg_msg_transmit                               ),
    .cfg_msg_transmit_type                            ( cfg_msg_transmit_type                          ),
    .cfg_msg_transmit_data                            ( cfg_msg_transmit_data                          ),
    .cfg_msg_transmit_done                            ( cfg_msg_transmit_done                          ),
    //  Configuration Flow Control Interface
    .cfg_fc_ph                                        ( cfg_fc_ph                                      ),
    .cfg_fc_pd                                        ( cfg_fc_pd                                      ),
    .cfg_fc_nph                                       ( cfg_fc_nph                                     ),
    .cfg_fc_npd                                       ( cfg_fc_npd                                     ),
    .cfg_fc_cplh                                      ( cfg_fc_cplh                                    ),
    .cfg_fc_cpld                                      ( cfg_fc_cpld                                    ),
    .cfg_fc_sel                                       ( cfg_fc_sel                                     ),
    //  Configuration Control Interface
    .cfg_hot_reset_in                                 ( cfg_hot_reset_in                               ),
    .cfg_hot_reset_out                                ( cfg_hot_reset_out                              ),
    .cfg_config_space_enable                          ( cfg_config_space_enable                        ),
    .cfg_dsn                                          ( cfg_dsn                                        ),
    .cfg_ds_bus_number                                ( cfg_ds_bus_number                              ),
    .cfg_ds_device_number                             ( cfg_ds_device_number                           ),
    .cfg_power_state_change_ack                       ( cfg_power_state_change_ack                     ),
    .cfg_power_state_change_interrupt                 ( cfg_power_state_change_interrupt               ),
    .cfg_ds_port_number                               ( cfg_ds_port_number                             ),
    .cfg_err_cor_in                                   ( cfg_err_cor_in                                 ),
    .cfg_err_cor_out                                  ( cfg_err_cor_out                                ),
    .cfg_err_fatal_out                                ( cfg_err_fatal_out                              ),
    .cfg_err_nonfatal_out                             ( cfg_err_nonfatal_out                           ),
    .cfg_err_uncor_in                                 ( cfg_err_uncor_in                               ),
    .cfg_flr_done                                     ( cfg_flr_done                                   ),
    .cfg_vf_flr_done                                  ( cfg_vf_flr_done                                ),
    .cfg_vf_flr_func_num                              ( cfg_vf_flr_func_num                            ),
    .cfg_flr_in_process                               ( cfg_flr_in_process                             ),
    .cfg_vf_flr_in_process                            ( cfg_vf_flr_in_process                          ),
    .cfg_req_pm_transition_l23_ready                  ( cfg_req_pm_transition_l23_ready                ),
    .cfg_link_training_enable                         ( cfg_link_training_enable                       ),
    .cfg_bus_number                                   ( cfg_bus_number                                 ),
    //  Configuration Interrupt Controller Interface
    .cfg_interrupt_int                                ( cfg_interrupt_int                              ),
    .cfg_interrupt_sent                               ( cfg_interrupt_sent                             ),
    .cfg_interrupt_pending                            ( cfg_interrupt_pending                          ),
    //  MSI Interrupt Interface
    .cfg_interrupt_msi_enable                         ( cfg_interrupt_msi_enable                       ),
    .cfg_interrupt_msi_int                            ( cfg_interrupt_msi_int                          ),
    .cfg_interrupt_msi_function_number                ( cfg_interrupt_msi_function_number              ),
    .cfg_interrupt_msi_sent                           ( cfg_interrupt_msi_sent                         ),
    .cfg_interrupt_msi_fail                           ( cfg_interrupt_msi_fail                         ),
    .cfg_interrupt_msi_mmenable                       ( cfg_interrupt_msi_mmenable                     ),
    .cfg_interrupt_msi_pending_status                 ( cfg_interrupt_msi_pending_status               ),
    .cfg_interrupt_msi_pending_status_function_num    ( cfg_interrupt_msi_pending_status_function_num  ),
    .cfg_interrupt_msi_pending_status_data_enable     ( cfg_interrupt_msi_pending_status_data_enable   ),
    .cfg_interrupt_msi_mask_update                    ( cfg_interrupt_msi_mask_update                  ),
    .cfg_interrupt_msi_select                         ( cfg_interrupt_msi_select                       ),
    .cfg_interrupt_msi_data                           ( cfg_interrupt_msi_data                         ),
    .cfg_interrupt_msi_attr                           ( cfg_interrupt_msi_attr                         ),
    .cfg_interrupt_msi_tph_present                    ( cfg_interrupt_msi_tph_present                  ),
    .cfg_interrupt_msi_tph_type                       ( cfg_interrupt_msi_tph_type                     ),
    .cfg_interrupt_msi_tph_st_tag                     ( cfg_interrupt_msi_tph_st_tag                   ),
  //  Configuration Extend Interface
    .cfg_ext_read_received                            ( cfg_ext_read_received                          ),
    .cfg_ext_write_received                           ( cfg_ext_write_received                         ),
    .cfg_ext_register_number                          ( cfg_ext_register_number                        ),
    .cfg_ext_function_number                          ( cfg_ext_function_number                        ),
    .cfg_ext_write_data                               ( cfg_ext_write_data                             ),
    .cfg_ext_write_byte_enable                        ( cfg_ext_write_byte_enable                      ),
    .cfg_ext_read_data                                ( cfg_ext_read_data                              ),
    .cfg_ext_read_data_valid                          ( cfg_ext_read_data_valid                        )
   );

  //  User_app Wrapper
  user_app_wrapper user_app_wrapper (
    //  Clock and Reset Interface
    .pcie_user_clk                                    ( pcie_user_clk                                  ),
    .pcie_user_reset                                  ( pcie_user_reset                                ),
    .pcie_phy_rdy_out                                 ( pcie_phy_rdy_out                               ),
    .pcie_user_lnk_up                                 ( pcie_user_lnk_up                               ),
    //  Requester Request Interface
    .pcie_rq_seq_num0                                 ( pcie_rq_seq_num0                               ),
    .pcie_rq_seq_num_vld0                             ( pcie_rq_seq_num_vld0                           ),
    .pcie_rq_tag0                                     ( pcie_rq_tag0                                   ),
    .pcie_rq_tag1                                     ( pcie_rq_tag1                                   ),
    .pcie_rq_tag_vld0                                 ( pcie_rq_tag_vld0                               ),
    .pcie_rq_tag_vld1                                 ( pcie_rq_tag_vld1                               ),
    .pcie_rq_seq_num1                                 ( pcie_rq_seq_num1                               ),
    .pcie_rq_seq_num_vld1                             ( pcie_rq_seq_num_vld1                           ),
    //  Power Management Interface
    .cfg_pm_aspm_l1_entry_reject                      ( cfg_pm_aspm_l1_entry_reject                    ),
    .cfg_pm_aspm_tx_l0s_entry_disable                 ( cfg_pm_aspm_tx_l0s_entry_disable               ),
    //  Configuration Management Interface
    .cfg_mgmt_addr                                    ( cfg_mgmt_addr                                  ),
    .cfg_mgmt_function_number                         ( cfg_mgmt_function_number                       ),
    .cfg_mgmt_write                                   ( cfg_mgmt_write                                 ),
    .cfg_mgmt_write_data                              ( cfg_mgmt_write_data                            ),
    .cfg_mgmt_byte_enable                             ( cfg_mgmt_byte_enable                           ),
    .cfg_mgmt_read                                    ( cfg_mgmt_read                                  ),
    .cfg_mgmt_read_data                               ( cfg_mgmt_read_data                             ),
    .cfg_mgmt_read_write_done                         ( cfg_mgmt_read_write_done                       ),
    .cfg_mgmt_debug_access                            ( cfg_mgmt_debug_access                          ),
    //  Configuration Status Interface
    .cfg_phy_link_down                                ( cfg_phy_link_down                              ),
    .cfg_phy_link_status                              ( cfg_phy_link_status                            ),
    .cfg_negotiated_width                             ( cfg_negotiated_width                           ),
    .cfg_current_speed                                ( cfg_current_speed                              ),
    .cfg_max_read_req                                 ( cfg_max_read_req                               ),
    .cfg_function_status                              ( cfg_function_status                            ),
    .cfg_vf_status                                    ( cfg_vf_status                                  ),
    .cfg_function_power_state                         ( cfg_function_power_state                       ),
    .cfg_vf_power_state                               ( cfg_vf_power_state                             ),
    .cfg_link_power_state                             ( cfg_link_power_state                           ),
    .cfg_local_error_out                              ( cfg_local_error_out                            ),
    .cfg_local_error_valid                            ( cfg_local_error_valid                          ),
    .cfg_rx_pm_state                                  ( cfg_rx_pm_state                                ),
    .cfg_tx_pm_state                                  ( cfg_tx_pm_state                                ),
    .cfg_ltssm_state                                  ( cfg_ltssm_state                                ),
    .cfg_rcb_status                                   ( cfg_rcb_status                                 ),
    .cfg_obff_enable                                  ( cfg_obff_enable                                ),
    .cfg_pl_status_change                             ( cfg_pl_status_change                           ),
    .cfg_tph_requester_enable                         ( cfg_tph_requester_enable                       ),
    .cfg_tph_st_mode                                  ( cfg_tph_st_mode                                ),
    .cfg_vf_tph_requester_enable                      ( cfg_vf_tph_requester_enable                    ),
    .cfg_vf_tph_st_mode                               ( cfg_vf_tph_st_mode                             ),
    .pcie_tfc_nph_av                                  ( pcie_tfc_nph_av                                ),
    .pcie_tfc_npd_av                                  ( pcie_tfc_npd_av                                ),
    .pcie_rq_tag_av                                   ( pcie_rq_tag_av                                 ),
    //  Configuration Received Message Interface
    .cfg_msg_received                                 ( cfg_msg_received                               ),
    .cfg_msg_received_data                            ( cfg_msg_received_data                          ),
    .cfg_msg_received_type                            ( cfg_msg_received_type                          ),
    //  Configuration Transmit Message Interface
    .cfg_msg_transmit                                 ( cfg_msg_transmit                               ),
    .cfg_msg_transmit_type                            ( cfg_msg_transmit_type                          ),
    .cfg_msg_transmit_data                            ( cfg_msg_transmit_data                          ),
    .cfg_msg_transmit_done                            ( cfg_msg_transmit_done                          ),
    //  Configuration Flow Control Interface
    .cfg_fc_ph                                        ( cfg_fc_ph                                      ),
    .cfg_fc_pd                                        ( cfg_fc_pd                                      ),
    .cfg_fc_nph                                       ( cfg_fc_nph                                     ),
    .cfg_fc_npd                                       ( cfg_fc_npd                                     ),
    .cfg_fc_cplh                                      ( cfg_fc_cplh                                    ),
    .cfg_fc_cpld                                      ( cfg_fc_cpld                                    ),
    .cfg_fc_sel                                       ( cfg_fc_sel                                     ),
    //  Configuration Control Interface
    .cfg_hot_reset_in                                 ( cfg_hot_reset_in                               ),
    .cfg_hot_reset_out                                ( cfg_hot_reset_out                              ),
    .cfg_config_space_enable                          ( cfg_config_space_enable                        ),
    .cfg_dsn                                          ( cfg_dsn                                        ),
    .cfg_ds_bus_number                                ( cfg_ds_bus_number                              ),
    .cfg_ds_device_number                             ( cfg_ds_device_number                           ),
    .cfg_power_state_change_ack                       ( cfg_power_state_change_ack                     ),
    .cfg_power_state_change_interrupt                 ( cfg_power_state_change_interrupt               ),
    .cfg_ds_port_number                               ( cfg_ds_port_number                             ),
    .cfg_err_cor_in                                   ( cfg_err_cor_in                                 ),
    .cfg_err_cor_out                                  ( cfg_err_cor_out                                ),
    .cfg_err_fatal_out                                ( cfg_err_fatal_out                              ),
    .cfg_err_nonfatal_out                             ( cfg_err_nonfatal_out                           ),
    .cfg_err_uncor_in                                 ( cfg_err_uncor_in                               ),
    .cfg_flr_done                                     ( cfg_flr_done                                   ),
    .cfg_vf_flr_done                                  ( cfg_vf_flr_done                                ),
    .cfg_vf_flr_func_num                              ( cfg_vf_flr_func_num                            ),
    .cfg_flr_in_process                               ( cfg_flr_in_process                             ),
    .cfg_vf_flr_in_process                            ( cfg_vf_flr_in_process                          ),
    .cfg_req_pm_transition_l23_ready                  ( cfg_req_pm_transition_l23_ready                ),
    .cfg_link_training_enable                         ( cfg_link_training_enable                       ),
    .cfg_bus_number                                   ( cfg_bus_number                                 ),
    //  Configuration Interrupt Controller Interface
    .cfg_interrupt_int                                ( cfg_interrupt_int                              ),
    .cfg_interrupt_sent                               ( cfg_interrupt_sent                             ),
    .cfg_interrupt_pending                            ( cfg_interrupt_pending                          ),
    //  MSI Interrupt Interface
    .cfg_interrupt_msi_enable                         ( cfg_interrupt_msi_enable                       ),
    .cfg_interrupt_msi_int                            ( cfg_interrupt_msi_int                          ),
    .cfg_interrupt_msi_function_number                ( cfg_interrupt_msi_function_number              ),
    .cfg_interrupt_msi_sent                           ( cfg_interrupt_msi_sent                         ),
    .cfg_interrupt_msi_fail                           ( cfg_interrupt_msi_fail                         ),
    .cfg_interrupt_msi_mmenable                       ( cfg_interrupt_msi_mmenable                     ),
    .cfg_interrupt_msi_pending_status                 ( cfg_interrupt_msi_pending_status               ),
    .cfg_interrupt_msi_pending_status_function_num    ( cfg_interrupt_msi_pending_status_function_num  ),
    .cfg_interrupt_msi_pending_status_data_enable     ( cfg_interrupt_msi_pending_status_data_enable   ),
    .cfg_interrupt_msi_mask_update                    ( cfg_interrupt_msi_mask_update                  ),
    .cfg_interrupt_msi_select                         ( cfg_interrupt_msi_select                       ),
    .cfg_interrupt_msi_data                           ( cfg_interrupt_msi_data                         ),
    .cfg_interrupt_msi_attr                           ( cfg_interrupt_msi_attr                         ),
    .cfg_interrupt_msi_tph_present                    ( cfg_interrupt_msi_tph_present                  ),
    .cfg_interrupt_msi_tph_type                       ( cfg_interrupt_msi_tph_type                     ),
    .cfg_interrupt_msi_tph_st_tag                     ( cfg_interrupt_msi_tph_st_tag                   ),
  //  Configuration Extend Interface
    .cfg_ext_read_received                            ( cfg_ext_read_received                          ),
    .cfg_ext_write_received                           ( cfg_ext_write_received                         ),
    .cfg_ext_register_number                          ( cfg_ext_register_number                        ),
    .cfg_ext_function_number                          ( cfg_ext_function_number                        ),
    .cfg_ext_write_data                               ( cfg_ext_write_data                             ),
    .cfg_ext_write_byte_enable                        ( cfg_ext_write_byte_enable                      ),
    .cfg_ext_read_data                                ( cfg_ext_read_data                              ),
    .cfg_ext_read_data_valid                          ( cfg_ext_read_data_valid                        )
  );

  assign pcie_rreq_tready = pcie_rreq_tready_i[0];
  assign pcie_cres_tready = pcie_cres_tready_i[0];

  wire   unconnected_pcie_tx_n_unc = |{1'b1, pcie_tx_n_unc};
  wire   unconnected_pcie_tx_p_unc = |{1'b1, pcie_tx_p_unc};

endmodule
