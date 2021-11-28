`define PCI_EXP_EP_DSN_1                                32'h00000000
`define PCI_EXP_EP_DSN_2                                32'h00000000

module user_app_wrapper
(

  //  Clock and Reset Interface
  input                                                 pcie_user_clk                                   ,
  input                                                 pcie_user_reset                                 ,
  input                                                 pcie_phy_rdy_out                                ,
  input                                                 pcie_user_lnk_up                                ,
  //  Requester Request Interface
  input                                                 pcie_rq_tag_vld0                                ,
  input                                                 pcie_rq_tag_vld1                                ,
  input  [  7:0]                                        pcie_rq_tag0                                    ,
  input  [  7:0]                                        pcie_rq_tag1                                    ,
  input  [  5:0]                                        pcie_rq_seq_num0                                ,
  input  [  5:0]                                        pcie_rq_seq_num1                                ,
  input                                                 pcie_rq_seq_num_vld0                            ,
  input                                                 pcie_rq_seq_num_vld1                            ,
  //  Power Management Interface
  output                                                cfg_pm_aspm_l1_entry_reject                     ,
  output                                                cfg_pm_aspm_tx_l0s_entry_disable                ,
  //  Configuration Management Interface
  output [  9:0]                                        cfg_mgmt_addr                                   ,
  output [  7:0]                                        cfg_mgmt_function_number                        ,
  output                                                cfg_mgmt_write                                  ,
  output [ 31:0]                                        cfg_mgmt_write_data                             ,
  output [  3:0]                                        cfg_mgmt_byte_enable                            ,
  output                                                cfg_mgmt_read                                   ,
  input  [ 31:0]                                        cfg_mgmt_read_data                              ,
  input                                                 cfg_mgmt_read_write_done                        ,
  output                                                cfg_mgmt_debug_access                           ,
  //  Configuration Status Interface
  input                                                 cfg_phy_link_down                               ,
  input  [  1:0]                                        cfg_phy_link_status                             ,
  input  [  2:0]                                        cfg_negotiated_width                            ,
  input  [  1:0]                                        cfg_current_speed                               ,
  input  [  2:0]                                        cfg_max_read_req                                ,
  input  [ 15:0]                                        cfg_function_status                             ,
  input  [503:0]                                        cfg_vf_status                                   ,
  input  [ 11:0]                                        cfg_function_power_state                        ,
  input  [755:0]                                        cfg_vf_power_state                              ,
  input  [  1:0]                                        cfg_link_power_state                            ,
  input  [  4:0]                                        cfg_local_error_out                             ,
  input                                                 cfg_local_error_valid                           ,
  input  [  1:0]                                        cfg_rx_pm_state                                 ,
  input  [  1:0]                                        cfg_tx_pm_state                                 ,
  input  [  5:0]                                        cfg_ltssm_state                                 ,
  input  [  3:0]                                        cfg_rcb_status                                  ,
  input  [  1:0]                                        cfg_obff_enable                                 ,
  input                                                 cfg_pl_status_change                            ,
  input  [  3:0]                                        cfg_tph_requester_enable                        ,
  input  [ 11:0]                                        cfg_tph_st_mode                                 ,
  input  [251:0]                                        cfg_vf_tph_requester_enable                     ,
  input  [755:0]                                        cfg_vf_tph_st_mode                              ,
  input  [  3:0]                                        pcie_tfc_nph_av                                 ,
  input  [  3:0]                                        pcie_tfc_npd_av                                 ,
  input  [  3:0]                                        pcie_rq_tag_av                                  ,
  //  Configuration Received Message Interface
  input                                                 cfg_msg_received                                ,
  input  [  7:0]                                        cfg_msg_received_data                           ,
  input  [  4:0]                                        cfg_msg_received_type                           ,
  //  Configuration Transmit Message Interface
  output                                                cfg_msg_transmit                                ,
  output [  2:0]                                        cfg_msg_transmit_type                           ,
  output [ 31:0]                                        cfg_msg_transmit_data                           ,
  input                                                 cfg_msg_transmit_done                           ,
  //  Configuration Flow Control Interface
  input  [  7:0]                                        cfg_fc_ph                                       ,
  input  [ 11:0]                                        cfg_fc_pd                                       ,
  input  [  7:0]                                        cfg_fc_nph                                      ,
  input  [ 11:0]                                        cfg_fc_npd                                      ,
  input  [  7:0]                                        cfg_fc_cplh                                     ,
  input  [ 11:0]                                        cfg_fc_cpld                                     ,
  output [  2:0]                                        cfg_fc_sel                                      ,
  //  Configuration Control Interface
  output                                                cfg_hot_reset_in                                ,
  input                                                 cfg_hot_reset_out                               ,
  output                                                cfg_config_space_enable                         ,
  output [ 63:0]                                        cfg_dsn                                         ,
  output [  7:0]                                        cfg_ds_bus_number                               ,
  output [  4:0]                                        cfg_ds_device_number                            ,
  output                                                cfg_power_state_change_ack                      ,
  input                                                 cfg_power_state_change_interrupt                ,
  output [  7:0]                                        cfg_ds_port_number                              ,
  output                                                cfg_err_cor_in                                  ,
  input                                                 cfg_err_cor_out                                 ,
  input                                                 cfg_err_fatal_out                               ,
  input                                                 cfg_err_nonfatal_out                            ,
  output                                                cfg_err_uncor_in                                ,
  output [  3:0]                                        cfg_flr_done                                    ,
  output                                                cfg_vf_flr_done                                 ,
  output [  7:0]                                        cfg_vf_flr_func_num                             ,
  input  [  3:0]                                        cfg_flr_in_process                              ,
  input  [251:0]                                        cfg_vf_flr_in_process                           ,
  output                                                cfg_req_pm_transition_l23_ready                 ,
  output                                                cfg_link_training_enable                        ,
  input  [  7:0]                                        cfg_bus_number                                  ,
  //  Configuration Interrupt Controller Interface
  output [  3:0]                                        cfg_interrupt_int                               ,
  input                                                 cfg_interrupt_sent                              ,
  output [  3:0]                                        cfg_interrupt_pending                           ,
  //  MSI Interrupt Interface
  input  [  3:0]                                        cfg_interrupt_msi_enable                        ,
  output [ 31:0]                                        cfg_interrupt_msi_int                           ,
  output [  7:0]                                        cfg_interrupt_msi_function_number               ,
  input                                                 cfg_interrupt_msi_sent                          ,
  input                                                 cfg_interrupt_msi_fail                          ,
  input  [ 11:0]                                        cfg_interrupt_msi_mmenable                      ,
  output [ 31:0]                                        cfg_interrupt_msi_pending_status                ,
  output [  1:0]                                        cfg_interrupt_msi_pending_status_function_num   ,
  output                                                cfg_interrupt_msi_pending_status_data_enable    ,
  input                                                 cfg_interrupt_msi_mask_update                   ,
  output [  1:0]                                        cfg_interrupt_msi_select                        ,
  input  [ 31:0]                                        cfg_interrupt_msi_data                          ,
  output [  2:0]                                        cfg_interrupt_msi_attr                          ,
  output                                                cfg_interrupt_msi_tph_present                   ,
  output [  1:0]                                        cfg_interrupt_msi_tph_type                      ,
  output [  7:0]                                        cfg_interrupt_msi_tph_st_tag                    ,
  //  Configuration Extend Interface
  input                                                 cfg_ext_read_received                           ,
  input                                                 cfg_ext_write_received                          ,
  input  [  9:0]                                        cfg_ext_register_number                         ,
  input  [  7:0]                                        cfg_ext_function_number                         ,
  input  [ 31:0]                                        cfg_ext_write_data                              ,
  input  [  3:0]                                        cfg_ext_write_byte_enable                       ,
  output [ 31:0]                                        cfg_ext_read_data                               ,
  output                                                cfg_ext_read_data_valid
);

  //
  // PCIe Function Level Reset done
  //

  reg  reg_cfg_flr_done;
  reg  reg_cfg_vf_flr_done;
  reg  reg_cfg_vf_flr_func_num;

  always @(posedge pcie_user_clk)
  begin
    if (pcie_user_reset) begin
      reg_cfg_flr_done      = 4'b0;
    end
    else begin
      reg_cfg_flr_done      = cfg_flr_in_process;
    end
  end

  always @(posedge pcie_user_clk)
  begin
    if (pcie_user_reset) begin
      reg_cfg_vf_flr_done   = 1'b0;
    end
    else begin
      reg_cfg_vf_flr_done   = |cfg_vf_flr_in_process[31:0];
    end
  end

  wire [ 4:0]      cfg_vf_flr_id;
  wire [31:0]      firstsetid;
  wire [31:0]      serial_or  = {cfg_vf_flr_in_process[30:0]  |  serial_or[30:0], 1'b0} ;
  assign           firstsetid =  cfg_vf_flr_in_process[31:0]  & ~serial_or;

  assign           cfg_vf_flr_id[0] = |(firstsetid & {16{{ 1{1'b1}}, { 1{1'b0}}}});
  assign           cfg_vf_flr_id[1] = |(firstsetid & { 8{{ 2{1'b1}}, { 2{1'b0}}}});
  assign           cfg_vf_flr_id[2] = |(firstsetid & { 4{{ 4{1'b1}}, { 4{1'b0}}}});
  assign           cfg_vf_flr_id[3] = |(firstsetid & { 2{{ 8{1'b1}}, { 8{1'b0}}}});
  assign           cfg_vf_flr_id[4] = |(firstsetid & { 1{{16{1'b1}}, {16{1'b0}}}});

  always @(posedge pcie_user_clk)
  begin
    if (pcie_user_reset) begin
      reg_cfg_vf_flr_func_num    = 8'b0;
    end
    else begin
      reg_cfg_vf_flr_func_num    = {3'b0, cfg_vf_flr_id};
    end
  end

  assign           cfg_flr_done                                      = reg_cfg_flr_done                           ;
  assign           cfg_vf_flr_done                                   = reg_cfg_vf_flr_done                        ;
  assign           cfg_vf_flr_func_num                               = reg_cfg_vf_flr_func_num                    ;


  //  Control Interface
  wire             unconnected_pcie_phy_rdy_out                      =  pcie_phy_rdy_out                          ;
  wire             unconnected_pcie_user_lnk_up                      =  pcie_user_lnk_up                          ;
  //  Requester Request Interface
  wire             unconnected_pcie_rq_tag_vld0                      =  pcie_rq_tag_vld0                          ;
  wire             unconnected_pcie_rq_tag_vld1                      =  pcie_rq_tag_vld1                          ;
  wire   [  7:0]   unconnected_pcie_rq_tag0                          =  pcie_rq_tag0                              ;
  wire   [  7:0]   unconnected_pcie_rq_tag1                          =  pcie_rq_tag1                              ;
  wire   [  5:0]   unconnected_pcie_rq_seq_num0                      =  pcie_rq_seq_num0                          ;
  wire   [  5:0]   unconnected_pcie_rq_seq_num1                      =  pcie_rq_seq_num1                          ;
  wire             unconnected_pcie_rq_seq_num_vld0                  =  pcie_rq_seq_num_vld0                      ;
  wire             unconnected_pcie_rq_seq_num_vld1                  =  pcie_rq_seq_num_vld1                      ;
  //  Power Management Interface
  assign           cfg_pm_aspm_l1_entry_reject                       =  1'b0                                      ;
  assign           cfg_pm_aspm_tx_l0s_entry_disable                  =  1'b1                                      ;
  //  Configuration Management Interface
  assign           cfg_mgmt_addr                                     =  10'h0                                     ;
  assign           cfg_mgmt_function_number                          =  8'b0                                      ;
  assign           cfg_mgmt_write                                    =  1'b0                                      ;
  assign           cfg_mgmt_write_data                               =  32'h0                                     ;
  assign           cfg_mgmt_byte_enable                              =  4'h0                                      ;
  assign           cfg_mgmt_read                                     =  1'b0                                      ;
  wire   [ 31:0]   unconnected_cfg_mgmt_read_data                    = cfg_mgmt_read_data                         ;
  wire             unconnected_cfg_mgmt_read_write_done              = cfg_mgmt_read_write_done                   ;
  assign           cfg_mgmt_debug_access                             =  1'b0                                      ;
  //  Configuration Status Interface
  wire             unconnected_cfg_phy_link_down                     = cfg_phy_link_down                          ;
  wire   [  1:0]   unconnected_cfg_phy_link_status                   = cfg_phy_link_status                        ;
  wire   [  2:0]   unconnected_cfg_negotiated_width                  = cfg_negotiated_width                       ;
  wire   [  1:0]   unconnected_cfg_current_speed                     = cfg_current_speed                          ;
  wire   [  2:0]   unconnected_cfg_max_read_req                      = cfg_max_read_req                           ;
  wire   [ 15:0]   unconnected_cfg_function_status                   = cfg_function_status                        ;
  wire   [503:0]   unconnected_cfg_vf_status                         = cfg_vf_status                              ;
  wire   [ 11:0]   unconnected_cfg_function_power_state              = cfg_function_power_state                   ;
  wire   [755:0]   unconnected_cfg_vf_power_state                    = cfg_vf_power_state                         ;
  wire   [  1:0]   unconnected_cfg_link_power_state                  = cfg_link_power_state                       ;
  wire   [  4:0]   unconnected_cfg_local_error_out                   = cfg_local_error_out                        ;
  wire             unconnected_cfg_local_error_valid                 = cfg_local_error_valid                      ;
  wire   [  1:0]   unconnected_cfg_rx_pm_state                       = cfg_rx_pm_state                            ;
  wire   [  1:0]   unconnected_cfg_tx_pm_state                       = cfg_tx_pm_state                            ;
  wire   [  5:0]   unconnected_cfg_ltssm_state                       = cfg_ltssm_state                            ;
  wire   [  3:0]   unconnected_cfg_rcb_status                        = cfg_rcb_status                             ;
  wire   [  1:0]   unconnected_cfg_obff_enable                       = cfg_obff_enable                            ;
  wire             unconnected_cfg_pl_status_change                  = cfg_pl_status_change                       ;
  wire   [  3:0]   unconnected_cfg_tph_requester_enable              = cfg_tph_requester_enable                   ;
  wire   [ 11:0]   unconnected_cfg_tph_st_mode                       = cfg_tph_st_mode                            ;
  wire   [251:0]   unconnected_cfg_vf_tph_requester_enable           = cfg_vf_tph_requester_enable                ;
  wire   [755:0]   unconnected_cfg_vf_tph_st_mode                    = cfg_vf_tph_st_mode                         ;
  wire   [  3:0]   unconnected_pcie_tfc_nph_av                       = pcie_tfc_nph_av                            ;
  wire   [  3:0]   unconnected_pcie_tfc_npd_av                       = pcie_tfc_npd_av                            ;
  wire   [  3:0]   unconnected_pcie_rq_tag_av                        = pcie_rq_tag_av                             ;
  //  Configuration Received Message Interface
  wire             unconnected_cfg_msg_received                      = cfg_msg_received                           ;
  wire   [  7:0]   unconnected_cfg_msg_received_data                 = cfg_msg_received_data                      ;
  wire   [  4:0]   unconnected_cfg_msg_received_type                 = cfg_msg_received_type                      ;
  //  Configuration Transmit Message Interface
  assign           cfg_msg_transmit                                  = 1'b0                                       ;
  assign           cfg_msg_transmit_type                             = 3'd0                                       ;
  assign           cfg_msg_transmit_data                             = 32'd0                                      ;
  wire             unconnected_cfg_msg_transmit_done                 = cfg_msg_transmit_done                      ;
  //  Configuration Flow Control Interface
  wire   [  7:0]   unconnected_cfg_fc_ph                             = cfg_fc_ph                                  ;
  wire   [ 11:0]   unconnected_cfg_fc_pd                             = cfg_fc_pd                                  ;
  wire   [  7:0]   unconnected_cfg_fc_nph                            = cfg_fc_nph                                 ;
  wire   [ 11:0]   unconnected_cfg_fc_npd                            = cfg_fc_npd                                 ;
  wire   [  7:0]   unconnected_cfg_fc_cplh                           = cfg_fc_cplh                                ;
  wire   [ 11:0]   unconnected_cfg_fc_cpld                           = cfg_fc_cpld                                ;
  assign           cfg_fc_sel                                        =  3'b0                                      ;
  //  Configuration Control Interface
  assign           cfg_hot_reset_in                                  =  1'b0                                      ;
  wire             unconnected_cfg_hot_reset_out                     = cfg_hot_reset_out                          ;
  assign           cfg_config_space_enable                           =  1'b1                                      ;
  assign           cfg_dsn                                           =  {`PCI_EXP_EP_DSN_2, `PCI_EXP_EP_DSN_1}    ;
  assign           cfg_ds_bus_number                                 =  8'b0                                      ;
  assign           cfg_ds_device_number                              =  5'b0                                      ;
  assign           cfg_power_state_change_ack                        =  1'b1                                      ;
  wire             unconnected_cfg_power_state_change_interrupt      =  cfg_power_state_change_interrupt          ;
  assign           cfg_ds_port_number                                =  8'b0                                      ;
  assign           cfg_err_cor_in                                    =  1'b0                                      ;
  wire             unconnected_cfg_err_cor_out                       = cfg_err_cor_out                            ;
  wire             unconnected_cfg_err_fatal_out                     = cfg_err_fatal_out                          ;
  wire             unconnected_cfg_err_nonfatal_out                  = cfg_err_nonfatal_out                       ;
  assign           cfg_err_uncor_in                                  =  1'b0                                      ;
  wire   [221:0]   unconnected_cfg_vf_flr_in_process                 = cfg_vf_flr_in_process[251:31]              ;
  assign           cfg_req_pm_transition_l23_ready                   =  1'b0                                      ;
  assign           cfg_link_training_enable                          =  1'b1                                      ;
  wire   [  7:0]   unconnected_cfg_bus_number                        = cfg_bus_number                             ;
  //  Configuration Interrupt Controller Interface
  assign           cfg_interrupt_int                                 = 4'd0                                       ;
  wire             cunconnected_cfg_interrupt_sent                   = cfg_interrupt_sent                         ;
  assign           cfg_interrupt_pending                             = 4'd0                                       ;
  //  MSI Interrupt Interface
  wire   [  3:0]   unconnected_cfg_interrupt_msi_enable              = cfg_interrupt_msi_enable                   ;
  assign           cfg_interrupt_msi_int                             = 32'd0                                      ;
  assign           cfg_interrupt_msi_function_number                 = 8'd0                                       ;
  wire             unconnected_cfg_interrupt_msi_sent                = cfg_interrupt_msi_sent                     ;
  wire             unconnected_cfg_interrupt_msi_fail                = cfg_interrupt_msi_fail                     ;
  wire   [ 11:0]   unconnected_cfg_interrupt_msi_mmenable            = cfg_interrupt_msi_mmenable                 ;
  assign           cfg_interrupt_msi_pending_status                  = 32'd0                                      ;
  assign           cfg_interrupt_msi_pending_status_function_num     = 2'd0                                       ;
  assign           cfg_interrupt_msi_pending_status_data_enable      = 1'b0                                       ;
  wire             unconnected_cfg_interrupt_msi_mask_update         = cfg_interrupt_msi_mask_update              ;
  assign           cfg_interrupt_msi_select                          = 2'd0                                       ;
  wire   [ 31:0]   unconnected_cfg_interrupt_msi_data                = cfg_interrupt_msi_data                     ;
  assign           cfg_interrupt_msi_attr                            = 3'd0                                       ;
  assign           cfg_interrupt_msi_tph_present                     = 1'b0                                       ;
  assign           cfg_interrupt_msi_tph_type                        = 2'd0                                       ;
  assign           cfg_interrupt_msi_tph_st_tag                      = 8'd0                                       ;
  //  Configuration Extend Interface
  wire             unconnected_cfg_ext_read_received                 = cfg_ext_read_received                      ;
  wire             unconnected_cfg_ext_write_received                = cfg_ext_write_received                     ;
  wire   [  9:0]   unconnected_cfg_ext_register_number               = cfg_ext_register_number                    ;
  wire   [  7:0]   unconnected_cfg_ext_function_number               = cfg_ext_function_number                    ;
  wire   [ 31:0]   unconnected_cfg_ext_write_data                    = cfg_ext_write_data                         ;
  wire   [  3:0]   unconnected_cfg_ext_write_byte_enable             = cfg_ext_write_byte_enable                  ;
  assign           cfg_ext_read_data                                 = 32'b0                                      ;
  assign           cfg_ext_read_data_valid                           = 1'b0                                       ;

endmodule
