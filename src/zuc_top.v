/*
 * Copyright (c) 2021 Gabi Malka.
 * Licensed under the 2-clause BSD license, see LICENSE for details.
 * SPDX-License-Identifier: BSD-2-Clause
 */
module zuc_top
(

  // PERST - active-low reset
  input                                pcie_perst                         ,
  
  // Reference clock - 100MHz
  input                                pcie_clk_n                         ,
  input                                pcie_clk_p                         ,

  // Rx IF x16 lanes
  input  [  7:0]                       pcie_rx_p                          ,
  input  [  7:0]                       pcie_rx_n                          ,

  // Tx IF x 8 lanes
  output [  7:0]                       pcie_tx_p                          ,
  output [  7:0]                       pcie_tx_n
);

`include "zuc_params.v"

  //
  // PCIe Interface
  //

  wire                                 pcie_user_clk                      ;
  wire                                 pcie_user_reset                    ;
  // Completer Request (RQ)
  wire                                 pcie_creq_tvalid                   ;
  wire                                 pcie_creq_tready                   ;
  wire   [511:0]                       pcie_creq_tdata                    ;
  wire   [ 15:0]                       pcie_creq_tkeep                    ;
  wire                                 pcie_creq_tlast                    ;
  wire   [182:0]                       pcie_creq_tuser                    ;
  wire   [  5:0]                       pcie_cq_np_req_count               ;
  wire   [  1:0]                       pcie_cq_np_req                     ;
  // Completer Response (CC)
  wire                                 pcie_cres_tvalid                   ;
  wire                                 pcie_cres_tready                   ;
  wire   [511:0]                       pcie_cres_tdata                    ;
  wire   [ 15:0]                       pcie_cres_tkeep                    ;
  wire                                 pcie_cres_tlast                    ;
  wire   [ 80:0]                       pcie_cres_tuser                    ;
  // Requester Request (RQ)
  wire                                 pcie_rreq_tvalid                   ;
  wire                                 pcie_rreq_tready                   ;
  wire   [511:0]                       pcie_rreq_tdata                    ;
  wire   [ 15:0]                       pcie_rreq_tkeep                    ;
  wire                                 pcie_rreq_tlast                    ;
  wire   [136:0]                       pcie_rreq_tuser                    ;
  // Requester Response (RC)
  wire   [511:0]                       pcie_rres_tdata                    ;
  wire   [ 15:0]                       pcie_rres_tkeep                    ;
  wire                                 pcie_rres_tlast                    ;
  wire                                 pcie_rres_tready                   ;
  wire                                 pcie_rres_tvalid                   ;
  wire   [160:0]                       pcie_rres_tuser                    ;
  // max payload size
  wire   [  1:0]                       cfg_max_payload                    ;

  pcie_core_wrapper pcie_core_wrapper
  (
    .pcie_perst                      ( pcie_perst                        ),
    .pcie_clk_p                      ( pcie_clk_p                        ),
    .pcie_clk_n                      ( pcie_clk_n                        ),
    .pcie_rx_p                       ( pcie_rx_p                         ),
    .pcie_rx_n                       ( pcie_rx_n                         ),
    .pcie_tx_p                       ( pcie_tx_p                         ),
    .pcie_tx_n                       ( pcie_tx_n                         ),

    .pcie_user_clk                   ( pcie_user_clk                     ),
    .pcie_user_reset                 ( pcie_user_reset                   ),

    // PCIe Completer Request (RQ)
    .pcie_creq_tvalid                ( pcie_creq_tvalid                  ),
    .pcie_creq_tready                ( pcie_creq_tready                  ),
    .pcie_creq_tdata                 ( pcie_creq_tdata                   ),
    .pcie_creq_tkeep                 ( pcie_creq_tkeep                   ),
    .pcie_creq_tlast                 ( pcie_creq_tlast                   ),
    .pcie_creq_tuser                 ( pcie_creq_tuser                   ),
    .pcie_cq_np_req                  ( pcie_cq_np_req                    ),
    .pcie_cq_np_req_count            ( pcie_cq_np_req_count              ),

    // PCIe Completer Response (CC)
    .pcie_cres_tvalid                ( pcie_cres_tvalid                  ),
    .pcie_cres_tready                ( pcie_cres_tready                  ),
    .pcie_cres_tdata                 ( pcie_cres_tdata                   ),
    .pcie_cres_tkeep                 ( pcie_cres_tkeep                   ),
    .pcie_cres_tlast                 ( pcie_cres_tlast                   ),
    .pcie_cres_tuser                 ( pcie_cres_tuser                   ),

    // PCIe Requester Request (RQ)
    .pcie_rreq_tvalid                ( pcie_rreq_tvalid                  ),
    .pcie_rreq_tready                ( pcie_rreq_tready                  ),
    .pcie_rreq_tdata                 ( pcie_rreq_tdata                   ),
    .pcie_rreq_tkeep                 ( pcie_rreq_tkeep                   ),
    .pcie_rreq_tlast                 ( pcie_rreq_tlast                   ),
    .pcie_rreq_tuser                 ( pcie_rreq_tuser                   ),

    // PCIe Requester Response(RC)
    .pcie_rres_tdata                 ( pcie_rres_tdata                   ),
    .pcie_rres_tkeep                 ( pcie_rres_tkeep                   ),
    .pcie_rres_tlast                 ( pcie_rres_tlast                   ),
    .pcie_rres_tready                ( pcie_rres_tready                  ),
    .pcie_rres_tvalid                ( pcie_rres_tvalid                  ),
    .pcie_rres_tuser                 ( pcie_rres_tuser                   ),

    .cfg_max_payload                 ( cfg_max_payload                   )
  );


  //
  // FlexConnect Instantiation
  //

  // Tx Input from User
  wire                                 usr2flc_dm_p0_tvalid               ;
  wire                                 usr2flc_dm_p0_tready               ;
  wire   [511:0]                       usr2flc_dm_p0_tdata                ;
  wire   [ 63:0]                       usr2flc_dm_p0_tkeep                ;
  wire                                 usr2flc_dm_p0_tlast                ;
  wire   [ 71:0]                       usr2flc_dm_p0_tuser                ;
  // Rx Output to User                                                    ;
  wire                                 flc2usr_dm_p0_tvalid               ;
  wire                                 flc2usr_dm_p0_tready               ;
  wire   [511:0]                       flc2usr_dm_p0_tdata                ;
  wire   [ 63:0]                       flc2usr_dm_p0_tkeep                ;
  wire                                 flc2usr_dm_p0_tlast                ;
  wire   [ 71:0]                       flc2usr_dm_p0_tuser                ;
  // Client Status                                                        ;
  wire                                 status_p0_rx_afull                 ;
  wire                                 status_p0_rx_full                  ;
  wire                                 status_p0_tx_afull                 ;
  wire                                 status_p0_tx_full                  ;
  wire                                 status_p0_tx_completion_valid      ;
  wire   [  9:0]                       status_p0_tx_completion_size       ;
  wire   [ 11:0]                       status_p0_tx_completion_queue      ;

  // Tx Input from User
  wire                                 usr2flc_dm_p1_tvalid               ;
  wire                                 usr2flc_dm_p1_tready               ;
  wire   [511:0]                       usr2flc_dm_p1_tdata                ;
  wire   [ 63:0]                       usr2flc_dm_p1_tkeep                ;
  wire                                 usr2flc_dm_p1_tlast                ;
  wire   [ 71:0]                       usr2flc_dm_p1_tuser                ;
  // Rx Output to User                                                    ;
  wire                                 flc2usr_dm_p1_tvalid               ;
  wire                                 flc2usr_dm_p1_tready               ;
  wire   [511:0]                       flc2usr_dm_p1_tdata                ;
  wire   [ 63:0]                       flc2usr_dm_p1_tkeep                ;
  wire                                 flc2usr_dm_p1_tlast                ;
  wire   [ 71:0]                       flc2usr_dm_p1_tuser                ;
  // Client Status                                                        ;
  wire                                 status_p1_rx_afull                 ;
  wire                                 status_p1_rx_full                  ;
  wire                                 status_p1_tx_afull                 ;
  wire                                 status_p1_tx_full                  ;
  wire                                 status_p1_tx_completion_valid      ;
  wire   [  9:0]                       status_p1_tx_completion_size       ;
  wire   [ 11:0]                       status_p1_tx_completion_queue      ;

  wire 				       afu_axilite_aw_rdy;
  wire 				       afu_axilite_aw_vld;
  wire [66:0] 			       afu_axilite_aw_addr;
  wire [2:0] 			       afu_axilite_aw_prot;
  wire 				       afu_axilite_w_rdy;
  wire 				       afu_axilite_w_vld;
  wire [35:0] 			       afu_axilite_w_data;
  wire [3:0] 			       afu_axilite_w_strobe;
  wire 				       afu_axilite_b_rdy;
  wire 				       afu_axilite_b_vld;
  wire [1:0] 			       afu_axilite_b_resp;
  wire 				       afu_axilite_ar_rdy;
  wire 				       afu_axilite_ar_vld;
  wire [66:0] 			       afu_axilite_ar_addr;
  wire [2:0] 			       afu_axilite_ar_prot;
  wire 				       afu_axilite_r_rdy;
  wire 				       afu_axilite_r_vld;
  wire [31:0] 			       afu_axilite_r_data;
  wire [1:0] 			       afu_axilite_r_resp;

  wire 				       flc_axilite_aw_rdy;
  wire 				       flc_axilite_aw_vld;
  wire [66:0] 			       flc_axilite_aw_addr;
  wire 				       flc_axilite_w_rdy;
  wire 				       flc_axilite_w_vld;
  wire [35:0] 			       flc_axilite_w_data;
  wire 				       flc_axilite_b_rdy;
  wire 				       flc_axilite_b_vld;
  wire [1:0] 			       flc_axilite_b_resp;
  wire 				       flc_axilite_ar_rdy;
  wire 				       flc_axilite_ar_vld;
  wire [66:0] 			       flc_axilite_ar_addr;
  wire 				       flc_axilite_r_rdy;
  wire 				       flc_axilite_r_vld;
  wire [31:0] 			       flc_axilite_r_data;

  wire 				       unconnected_axilite_aw_rdy;
  wire 				       unconnected_axilite_aw_vld;
  wire [66:0] 			       unconnected_axilite_aw_addr;
  wire [2:0] 			       unconnected_axilite_aw_prot;
  wire 				       unconnected_axilite_w_rdy;
  wire 				       unconnected_axilite_w_vld;
  wire [35:0] 			       unconnected_axilite_w_data;
  wire [3:0] 			       unconnected_axilite_w_strobe;
  wire 				       unconnected_axilite_b_rdy;
  wire 				       unconnected_axilite_b_vld;
  wire [1:0] 			       unconnected_axilite_b_resp;
  wire 				       unconnected_axilite_ar_rdy;
  wire 				       unconnected_axilite_ar_vld;
  wire [66:0] 			       unconnected_axilite_ar_addr;
  wire [2:0] 			       unconnected_axilite_ar_prot;
  wire 				       unconnected_axilite_r_rdy;
  wire 				       unconnected_axilite_r_vld;
  wire [31:0] 			       unconnected_axilite_r_data;
  wire [1:0] 			       unconnected_axilite_r_resp;
  wire 				       axilite_disabled;
  
  assign unconnected_axilite_aw_vld = 1'b0;
  assign unconnected_axilite_aw_addr = 64'b0;
  assign unconnected_axilite_aw_prot = 3'b0;
  assign unconnected_axilite_w_vld = 1'b0;
  assign unconnected_axilite_w_data = 32'b0;
  assign unconnected_axilite_w_strobe = 4'b0;
  assign unconnected_axilite_b_rdy = 1'b0;
  assign unconnected_axilite_ar_vld = 1'b0;
  assign unconnected_axilite_ar_addr = 64'b0;
  assign unconnected_axilite_ar_prot = 3'b0;
  assign unconnected_axilite_r_rdy = 1'b0;
  assign axilite_disabled = 1'b0;

  flc
  mellanox_flc
  (
    .clk                             ( pcie_user_clk                     ),
    .reset                           ( pcie_user_reset                   ),

    // PCIe Completer Request (RQ)
    .pcie_creq_tvalid                ( pcie_creq_tvalid                  ),
    .pcie_creq_tready                ( pcie_creq_tready                  ),
    .pcie_creq_tdata                 ( pcie_creq_tdata                   ),
    .pcie_creq_tkeep                 ( pcie_creq_tkeep                   ),
    .pcie_creq_tlast                 ( pcie_creq_tlast                   ),
    .pcie_creq_tuser                 ( pcie_creq_tuser                   ),
    .pcie_cq_np_req_count            ( pcie_cq_np_req_count              ),
    .pcie_cq_np_req                  ( pcie_cq_np_req                    ),
    // PCIe Completer Response (CC)
    .pcie_cres_tvalid                ( pcie_cres_tvalid                  ),
    .pcie_cres_tready                ( pcie_cres_tready                  ),
    .pcie_cres_tdata                 ( pcie_cres_tdata                   ),
    .pcie_cres_tkeep                 ( pcie_cres_tkeep                   ),
    .pcie_cres_tlast                 ( pcie_cres_tlast                   ),
    .pcie_cres_tuser                 ( pcie_cres_tuser                   ),
    // PCIe Requester Request (RQ)
    .pcie_rreq_tvalid                ( pcie_rreq_tvalid                  ),
    .pcie_rreq_tready                ( pcie_rreq_tready                  ),
    .pcie_rreq_tdata                 ( pcie_rreq_tdata                   ),
    .pcie_rreq_tkeep                 ( pcie_rreq_tkeep                   ),
    .pcie_rreq_tlast                 ( pcie_rreq_tlast                   ),
    .pcie_rreq_tuser                 ( pcie_rreq_tuser                   ),
    .pcie_rres_tdata                 ( pcie_rres_tdata                   ),
    // PCIe Requester Response(RC)
    .pcie_rres_tkeep                 ( pcie_rres_tkeep                   ),
    .pcie_rres_tlast                 ( pcie_rres_tlast                   ),
    .pcie_rres_tready                ( pcie_rres_tready                  ),
    .pcie_rres_tvalid                ( pcie_rres_tvalid                  ),
    .pcie_rres_tuser                 ( pcie_rres_tuser                   ),

    .cfg_max_payload                 ( cfg_max_payload                   ),

`ifdef AXI4LITE_EN
    .m_axi4lite_aw__rdy              ( flc_axilite_aw_rdy                ),
`endif
`ifndef AXI4LITE_EN
    .m_axi4lite_aw__rdy              ( axilite_disabled                  ),
`endif

    .m_axi4lite_aw                   ( flc_axilite_aw_addr               ),
    .m_axi4lite_aw__vld              ( flc_axilite_aw_vld                ),
    .m_axi4lite_w                    ( flc_axilite_w_data                ),
    .m_axi4lite_w__vld               ( flc_axilite_w_vld                 ),
    .m_axi4lite_w__rdy               ( flc_axilite_w_rdy                 ),
    .m_axi4lite_b                    ( flc_axilite_b_resp                ),
    .m_axi4lite_b__vld               ( flc_axilite_b_vld                 ),
    .m_axi4lite_b__rdy               ( flc_axilite_b_rdy                 ),
    .m_axi4lite_ar                   ( flc_axilite_ar_addr               ),
    .m_axi4lite_ar__vld              ( flc_axilite_ar_vld                ),
    .m_axi4lite_ar__rdy              ( flc_axilite_ar_rdy                ),
    .m_axi4lite_r                    ( flc_axilite_r_data                ),
    .m_axi4lite_r__vld               ( flc_axilite_r_vld                 ),
    .m_axi4lite_r__rdy               ( flc_axilite_r_rdy                 ),

    // Client-0 signal
    //Tx Input from User
    .usr2flc_dm_p0_tvalid            ( usr2flc_dm_p0_tvalid              ),
    .usr2flc_dm_p0_tready            ( usr2flc_dm_p0_tready              ),
    .usr2flc_dm_p0_tdata             ( usr2flc_dm_p0_tdata               ),
    .usr2flc_dm_p0_tkeep             ( usr2flc_dm_p0_tkeep               ),
    .usr2flc_dm_p0_tlast             ( usr2flc_dm_p0_tlast               ),
    .usr2flc_dm_p0_tuser             ( usr2flc_dm_p0_tuser               ),
    //Rx Output to User
    .flc2usr_dm_p0_tvalid            ( flc2usr_dm_p0_tvalid              ),
    .flc2usr_dm_p0_tready            ( flc2usr_dm_p0_tready              ),
    .flc2usr_dm_p0_tdata             ( flc2usr_dm_p0_tdata               ),
    .flc2usr_dm_p0_tkeep             ( flc2usr_dm_p0_tkeep               ),
    .flc2usr_dm_p0_tlast             ( flc2usr_dm_p0_tlast               ),
    .flc2usr_dm_p0_tuser             ( flc2usr_dm_p0_tuser               ),
    //Client Status
    .status_p0_rx_afull              ( status_p0_rx_afull                ),
    .status_p0_rx_full               ( status_p0_rx_full                 ),
    .status_p0_tx_afull              ( status_p0_tx_afull                ),
    .status_p0_tx_full               ( status_p0_tx_full                 ),
    .status_p0_tx_completion_valid   ( status_p0_tx_completion_valid     ),
    .status_p0_tx_completion_size    ( status_p0_tx_completion_size      ),
    .status_p0_tx_completion_queue   ( status_p0_tx_completion_queue     )

    `ifdef TWO_SLICES
      // Client-1 signal
      //Tx Input from User
     ,.usr2flc_dm_p1_tvalid            ( usr2flc_dm_p1_tvalid              ),
      .usr2flc_dm_p1_tready            ( usr2flc_dm_p1_tready              ),
      .usr2flc_dm_p1_tdata             ( usr2flc_dm_p1_tdata               ),
      .usr2flc_dm_p1_tkeep             ( usr2flc_dm_p1_tkeep               ),
      .usr2flc_dm_p1_tlast             ( usr2flc_dm_p1_tlast               ),
      .usr2flc_dm_p1_tuser             ( usr2flc_dm_p1_tuser               ),
      //Rx Output to User
      .flc2usr_dm_p1_tvalid            ( flc2usr_dm_p1_tvalid              ),
      .flc2usr_dm_p1_tready            ( flc2usr_dm_p1_tready              ),
      .flc2usr_dm_p1_tdata             ( flc2usr_dm_p1_tdata               ),
      .flc2usr_dm_p1_tkeep             ( flc2usr_dm_p1_tkeep               ),
      .flc2usr_dm_p1_tlast             ( flc2usr_dm_p1_tlast               ),
      .flc2usr_dm_p1_tuser             ( flc2usr_dm_p1_tuser               ),
      //Client Status
      .status_p1_rx_afull              ( status_p1_rx_afull                ),
      .status_p1_rx_full               ( status_p1_rx_full                 ),
      .status_p1_tx_afull              ( status_p1_tx_afull                ),
      .status_p1_tx_full               ( status_p1_tx_full                 ),
      .status_p1_tx_completion_valid   ( status_p1_tx_completion_valid     ),
      .status_p1_tx_completion_size    ( status_p1_tx_completion_size      ),
      .status_p1_tx_completion_queue   ( status_p1_tx_completion_queue     )
    `endif
  );
 
  //
  // ZUC AFU Instantiation
  //

  wire   [ 71:0]                       flc2usr_dm_p0_tuser_q0             ;
  assign flc2usr_dm_p0_tuser_q0 =    { flc2usr_dm_p0_tuser[71:16]         ,
	                               15'b0                              ,
	                               flc2usr_dm_p0_tuser[56]           };
  wire 				       flc_pci_sample_soft_reset;
  wire [1:0] 			       flc_pci_sample_enable;
  wire [63:0] 			       afu_events;
  
// dm_p1 interconnect is not used:
  assign flc2usr_dm_p1_tready = 1'b0;
  assign usr2flc_dm_p1_tvalid = 1'b0;
  assign usr2flc_dm_p1_tdata = 512'b0;
  assign usr2flc_dm_p1_tkeep = 64'b0;
  assign usr2flc_dm_p1_tlast = 1'b0;
  assign usr2flc_dm_p1_tuser = 72'b0;
  

  // Clock domains synchronizer
  // 1. zuc clock generation, given the 100 Mhz clock
  // 2. Adding two dual clock fifos to synch betwen the pcie and the zuc AXI streams

  wire 				       usr2zuc_tvalid;
  wire 				       usr2zuc_tready;
  wire [511:0] 			       usr2zuc_tdata;
  wire [63:0] 			       usr2zuc_tkeep;
  wire 				       usr2zuc_tlast;
  wire [71:0] 			       usr2zuc_tuser;
  wire 				       zuc2usr_tvalid;
  wire 				       zuc2usr_tready;
  wire [511:0] 			       zuc2usr_tdata;
  wire [63:0] 			       zuc2usr_tkeep;
  wire 				       zuc2usr_tlast;
  wire [71:0] 			       zuc2usr_tuser;

  // ==========================================================================
  // zuc_afu clock & reset:
  // ==========================================================================
  // zuc_afu clock
  // 1. Using clocking wizard to generate the following clock generator
  //
  // zuc_afu reset
  // 1. zuc_clk_locked is asserted TBD clocks after zuc_clk started toggling,
  // 2. zuc_reset is asserted during this period 
  localparam ZUC_RESET_DURATION = 32;
  wire 				       zuc_clk;
  wire 				       zuc_clk_locked;
  reg 				       zuc_reset;
  reg [7:0] 			       zuc_reset_timer;

  // zuc clk modules options:
  // clk_125mhz
  // clk_166mhz
  // clk_183mhz
  // clk_200mhz
  // clk_220mhz
  // clk_222mhz
  // clk_250mhz
  clk_200mhz zuc_clk_inst 
    (
     .clk_in1(pcie_user_clk),     // Input 250 Mhz clk
     .reset(pcie_user_reset),     // input reset
     .locked(zuc_clk_locked),     // output
     .clk_out1(zuc_clk)           // output zuc clk
     );
  
  always @(posedge (zuc_clk || zuc_clk_locked)) begin
    if (zuc_clk_locked && ~zuc_clk)
      // This block is entered only once, after zuc_clk_locked is asserted.
      // zuc_clk_locked is the first to rise (while the clock still flat), since the clock module is configured with "Safe Clock Startup"
      begin
	zuc_reset_timer <= 8'h00;
	zuc_reset <= 1'b1;
      end

    // The remaining blocks are entered on zuc_clk rise
    else if (zuc_reset_timer < ZUC_RESET_DURATION)
      zuc_reset_timer <= zuc_reset_timer + 8'h01;
    else
      zuc_reset <= 1'b0;
  end

  
  wire soft_reset;
  // ==========================================================================
  // zuc_afu:
  // ==========================================================================
  zuc_afu zuc_afu(
		  .clk(zuc_clk),
		  .reset(zuc_reset),
		  .afu_soft_reset(soft_reset),
		  
		  .pci2sbu_axi4stream_vld(usr2zuc_tvalid),
		  .pci2sbu_axi4stream_rdy(usr2zuc_tready),
		  .pci2sbu_axi4stream_tdata(usr2zuc_tdata),
		  .pci2sbu_axi4stream_tkeep(usr2zuc_tkeep),
		  .pci2sbu_axi4stream_tlast(usr2zuc_tlast),
		  .pci2sbu_axi4stream_tuser(usr2zuc_tuser),
		  
		  .sbu2pci_axi4stream_vld(zuc2usr_tvalid),
		  .sbu2pci_axi4stream_rdy(zuc2usr_tready),
		  .sbu2pci_axi4stream_tdata(zuc2usr_tdata),
		  .sbu2pci_axi4stream_tkeep(zuc2usr_tkeep),
		  .sbu2pci_axi4stream_tlast(zuc2usr_tlast),
		  .sbu2pci_axi4stream_tuser(zuc2usr_tuser),

    `ifdef AXI4LITE_EN
		  .axilite_aw_vld(afu_axilite_aw_vld),
    `endif
    `ifndef AXI4LITE_EN
		  .axilite_aw_vld(axilite_disabled),
    `endif

		  .axilite_aw_rdy(afu_axilite_aw_rdy),
		  .axilite_aw_addr(afu_axilite_aw_addr[63:0]),
		  .axilite_aw_prot(afu_axilite_aw_prot),
		  .axilite_w_vld(afu_axilite_w_vld),
		  .axilite_w_rdy(afu_axilite_w_rdy),
		  .axilite_w_data(afu_axilite_w_data[31:0]),
		  .axilite_w_strobe(afu_axilite_w_strobe),
		  .axilite_b_vld(afu_axilite_b_vld),
		  .axilite_b_rdy(afu_axilite_b_rdy),
		  .axilite_b_resp(afu_axilite_b_resp),
		  .axilite_ar_vld(afu_axilite_ar_vld),
		  .axilite_ar_rdy(afu_axilite_ar_rdy),
		  .axilite_ar_addr(afu_axilite_ar_addr[63:0]),
		  .axilite_ar_prot(afu_axilite_ar_prot),
		  .axilite_r_vld(afu_axilite_r_vld),
		  .axilite_r_rdy(afu_axilite_r_rdy),
		  .axilite_r_data(afu_axilite_r_data),
		  .axilite_r_resp(afu_axilite_r_resp),

		  .flc_pci_sample_soft_reset(flc_pci_sample_soft_reset),
		  .flc_pci_sample_enable(flc_pci_sample_enable),
		  .afu_events(afu_events)
		  );

  wire [9:0] flc2usr_wr_data_count; // For simulation purposes. Will be optimized out at synthesis
  wire [9:0] usr2zuc_rd_data_count; // For simulation purposes. Will be optimized out at synthesis
  wire [9:0] zuc2usr_wr_data_count; // For simulation purposes. Will be optimized out at synthesis
  wire [9:0] usr2flc_rd_data_count; // For simulation purposes. Will be optimized out at synthesis
  wire 	     unconnected_flc2usr_wr_rst_busy;
  wire 	     unconnected_usr2zuc_rd_rst_busy;
  wire 	     unconnected_zuc2usr_wr_rst_busy;
  wire 	     unconnected_usr2flc_rd_rst_busy;
  

  // Dual clock axi4-stream BRAM fifos, to synch between the pci and zuc cloc kdomains(250Mhz pcie stream and 200/222 Mhz)
  axis_512x649_fifo_dual_clk
    pcie2user_clksync_fifo (
			    .wr_rst_busy(unconnected_flc2usr_wr_rst_busy),    // Available only for UltraScale device built-in FIFOS
			    .rd_rst_busy(unconnected_usr2zuc_rd_rst_busy),    // Available only for UltraScale device built-in FIFOS
			    .s_aclk(pcie_user_clk),                           // input wire s_aclk
			    .s_aresetn(~(zuc_reset)),                         // input wire s_aresetn
			    .s_axis_tvalid(flc2usr_dm_p0_tvalid),             // input wire s_axis_tvalid
			    .s_axis_tready(flc2usr_dm_p0_tready),             // output wire s_axis_tready
			    .s_axis_tdata(flc2usr_dm_p0_tdata),               // input wire [511 : 0] s_axis_tdata
			    .s_axis_tkeep(flc2usr_dm_p0_tkeep),               // input wire [63 : 0] s_axis_tkeep
			    .s_axis_tlast(flc2usr_dm_p0_tlast),               // input wire s_axis_tlast
			    .s_axis_tuser(flc2usr_dm_p0_tuser_q0),            // input wire [71 : 0] s_axis_tuser
			    .m_aclk(zuc_clk),                                 // input wire m_aclk
			    .m_axis_tvalid(usr2zuc_tvalid),                   // output wire m_axis_tvalid
			    .m_axis_tready(usr2zuc_tready),                   // input wire m_axis_tready
			    .m_axis_tdata(usr2zuc_tdata),                     // output wire [511 : 0] m_axis_tdata
			    .m_axis_tkeep(usr2zuc_tkeep),                     // output wire [63 : 0] m_axis_tkeep
			    .m_axis_tlast(usr2zuc_tlast),                     // output wire m_axis_tlast
			    .m_axis_tuser(usr2zuc_tuser),                      // output wire [71 : 0] m_axis_tuser
			    .axis_wr_data_count(flc2usr_wr_data_count),       // output wire [9 : 0] axis_wr_data_count
			    .axis_rd_data_count(usr2zuc_rd_data_count)        // output wire [9 : 0] axis_rd_data_count
			    );
  
  axis_512x649_fifo_dual_clk
    user2pcie_clksync_fifo (
			    .wr_rst_busy(unconnected_zuc2usr_wr_rst_busy),    // Available only for UltraScale device built-in FIFOS
			    .rd_rst_busy(unconnected_usr2flc_rd_rst_busy),    // Available only for UltraScale device built-in FIFOS
			    .s_aclk(zuc_clk),                                 // input wire s_aclk
			    .s_aresetn(~(zuc_reset)),                         // input wire s_aresetn
			    .s_axis_tvalid(zuc2usr_tvalid),                   // input wire s_axis_tvalid
			    .s_axis_tready(zuc2usr_tready),                   // output wire s_axis_tready
			    .s_axis_tdata(zuc2usr_tdata),                     // input wire [511 : 0] s_axis_tdata
			    .s_axis_tkeep(zuc2usr_tkeep),                     // input wire [63 : 0] s_axis_tkeep
			    .s_axis_tlast(zuc2usr_tlast),                     // input wire s_axis_tlast
			    .s_axis_tuser(zuc2usr_tuser),                     // input wire [71 : 0] s_axis_tuser
			    .m_aclk(pcie_user_clk),                           // input wire m_aclk
			    .m_axis_tvalid(usr2flc_dm_p0_tvalid),             // output wire m_axis_tvalid
			    .m_axis_tready(usr2flc_dm_p0_tready),             // input wire m_axis_tready
			    .m_axis_tdata(usr2flc_dm_p0_tdata),               // output wire [511 : 0] m_axis_tdata
			    .m_axis_tkeep(usr2flc_dm_p0_tkeep),               // output wire [63 : 0] m_axis_tkeep
			    .m_axis_tlast(usr2flc_dm_p0_tlast),               // output wire m_axis_tlast
			    .m_axis_tuser(usr2flc_dm_p0_tuser),                // output wire [71 : 0] m_axis_tuser
			    .axis_wr_data_count(zuc2usr_wr_data_count),       // output wire [9 : 0] axis_wr_data_count
			    .axis_rd_data_count(usr2flc_rd_data_count)        // output wire [9 : 0] axis_rd_data_count
			    );
  

  // axi4lite synch between flc and afu clock domains: 
  wire [31:0] axi4liteM0_awaddr;
  wire [2:0]  axi4liteM0_awprot;
  wire 	      axi4liteM0_awvalid;
  wire 	      axi4liteM0_awready;
  wire [31:0] axi4liteM0_wdata;
  wire [3:0]  axi4liteM0_wstrb;
  wire 	      axi4liteM0_wvalid;
  wire 	      axi4liteM0_wready;
  wire [1:0]  axi4liteM0_bresp;
  wire 	      axi4liteM0_bvalid;
  wire 	      axi4liteM0_bready;
  wire [31:0] axi4liteM0_araddr;
  wire [2:0]  axi4liteM0_arprot;
  wire 	      axi4liteM0_arvalid;
  wire 	      axi4liteM0_arready;
  wire [31:0] axi4liteM0_rdata;
  wire [1:0]  axi4liteM0_rresp;
  wire 	      axi4liteM0_rvalid;
  wire 	      axi4liteM0_rready;

  axi4lite_clock_converter axi4lite_flc2afu 
    (
     .s_axi_aclk(pcie_user_clk),            // input wire s_axi_aclk
     .s_axi_aresetn(~pcie_user_reset),      // input wire s_axi_aresetn
     //	 .s_axi_awaddr(flc_axilite_aw_addr),    // input wire [63 : 0] s_axi_awaddr
     //	 .s_axi_awprot(unconnected_axilite_aw_prot),    // input wire [2 : 0] s_axi_awprot
     //	 .s_axi_awvalid(flc_axilite_aw_vld),  // input wire s_axi_awvalid
     //	 .s_axi_awready(flc_axilite_aw_rdy),  // output wire s_axi_awready
     //	 .s_axi_wdata(flc_axilite_w_data),      // input wire [31 : 0] s_axi_wdata
     //	 .s_axi_wstrb(unconnected_axilite_w_strobe),      // input wire [3 : 0] s_axi_wstrb
     //	 .s_axi_wvalid(flc_axilite_w_vld),    // input wire s_axi_wvalid
     //	 .s_axi_wready(flc_axilite_w_rdy),    // output wire s_axi_wready
     //	 .s_axi_bresp(flc_axilite_b_resp),      // output wire [1 : 0] s_axi_bresp
     //	 .s_axi_bvalid(flc_axilite_b_vld),    // output wire s_axi_bvalid
     //	 .s_axi_bready(flc_axilite_b_rdy),    // input wire s_axi_bready
     //	 .s_axi_araddr(flc_axilite_ar_addr),    // input wire [63 : 0] s_axi_araddr
     //	 .s_axi_arprot(unconnected_axilite_ar_prot),    // input wire [2 : 0] s_axi_arprot
     //	 .s_axi_arvalid(flc_axilite_ar_vld),  // input wire s_axi_arvalid
     //	 .s_axi_arready(flc_axilite_ar_rdy),  // output wire s_axi_arready
     //	 .s_axi_rdata(flc_axilite_r_data),      // output wire [31 : 0] s_axi_rdata
     //	 .s_axi_rresp(unconnected_axilite_r_resp),      // output wire [1 : 0] s_axi_rresp
     //	 .s_axi_rvalid(flc_axilite_r_vld),    // output wire s_axi_rvalid
     //	 .s_axi_rready(flc_axilite_r_rdy),    // input wire s_axi_rready
     .s_axi_awaddr(axi4liteM0_awaddr),    // input wire [31 : 0] s_axi_awaddr
     .s_axi_awprot(axi4liteM0_awprot),    // input wire [2 : 0] s_axi_awprot
     .s_axi_awvalid(axi4liteM0_awvalid),  // input wire s_axi_awvalid
     .s_axi_awready(axi4liteM0_awready),  // output wire s_axi_awready
     .s_axi_wdata(axi4liteM0_wdata),      // input wire [31 : 0] s_axi_wdata
     .s_axi_wstrb(axi4liteM0_wstrb),      // input wire [3 : 0] s_axi_wstrb
     .s_axi_wvalid(axi4liteM0_wvalid),    // input wire s_axi_wvalid
     .s_axi_wready(axi4liteM0_wready),    // output wire s_axi_wready
     .s_axi_bresp(axi4liteM0_bresp),      // output wire [1 : 0] s_axi_bresp
     .s_axi_bvalid(axi4liteM0_bvalid),    // output wire s_axi_bvalid
     .s_axi_bready(axi4liteM0_bready),    // input wire s_axi_bready
     .s_axi_araddr(axi4liteM0_araddr),    // input wire [31 : 0] s_axi_araddr
     .s_axi_arprot(axi4liteM0_arprot),    // input wire [2 : 0] s_axi_arprot
     .s_axi_arvalid(axi4liteM0_arvalid),  // input wire s_axi_arvalid
     .s_axi_arready(axi4liteM0_arready),  // output wire s_axi_arready
     .s_axi_rdata(axi4liteM0_rdata),      // output wire [31 : 0] s_axi_rdata
     .s_axi_rresp(axi4liteM0_rresp),      // output wire [1 : 0] s_axi_rresp
     .s_axi_rvalid(axi4liteM0_rvalid),    // output wire s_axi_rvalid
     .s_axi_rready(axi4liteM0_rready),    // input wire s_axi_rready
     
     .m_axi_aclk(zuc_clk),                // input wire m_axi_aclk
     .m_axi_aresetn(~zuc_reset),          // input wire m_axi_aresetn
     .m_axi_awaddr(afu_axilite_aw_addr),    // output wire [63 : 0] m_axi_awaddr
     .m_axi_awprot(afu_axilite_aw_prot),    // output wire [2 : 0] m_axi_awprot
     .m_axi_awvalid(afu_axilite_aw_vld),  // output wire m_axi_awvalid
     .m_axi_awready(afu_axilite_aw_rdy),  // input wire m_axi_awready
     .m_axi_wdata(afu_axilite_w_data),      // output wire [31 : 0] m_axi_wdata
     .m_axi_wstrb(afu_axilite_w_strobe),      // output wire [3 : 0] m_axi_wstrb
     .m_axi_wvalid(afu_axilite_w_vld),    // output wire m_axi_wvalid
     .m_axi_wready(afu_axilite_w_rdy),    // input wire m_axi_wready
     .m_axi_bresp(afu_axilite_b_resp),      // input wire [1 : 0] m_axi_bresp
     .m_axi_bvalid(afu_axilite_b_vld),    // input wire m_axi_bvalid
     .m_axi_bready(afu_axilite_b_rdy),    // output wire m_axi_bready
     .m_axi_araddr(afu_axilite_ar_addr),    // output wire [63 : 0] m_axi_araddr
     .m_axi_arprot(afu_axilite_ar_prot),    // output wire [2 : 0] m_axi_arprot
     .m_axi_arvalid(afu_axilite_ar_vld),  // output wire m_axi_arvalid
     .m_axi_arready(afu_axilite_ar_rdy),  // input wire m_axi_arready
     .m_axi_rdata(afu_axilite_r_data),      // input wire [31 : 0] m_axi_rdata
     .m_axi_rresp(afu_axilite_r_resp),      // input wire [1 : 0] m_axi_rresp
     .m_axi_rvalid(afu_axilite_r_vld),    // input wire m_axi_rvalid
     .m_axi_rready(afu_axilite_r_rdy)    // output wire m_axi_rready
     );
  
  // AXI4Lite crossbar
  // Connecting the host to two slaves:
  // M0: zuc_afu axi4lite
  // M1 pci2sbu & sbu2pci sampling fifos
  //
  wire 	      axi4liteM1_awready, axi4liteM1_wready, axi4liteM1_bvalid;
  wire [31:0] axi4liteM1_araddr;
  wire [31:0] axi4liteM1_rdata;
  wire [1:0]  axi4liteM1_rresp;
  wire [1:0]  axi4liteM1_bresp;
  
  // M1 is read_only. The write part is disabled
  assign axi4liteM1_awready = 1'b0;
  assign axi4liteM1_wready = 1'b0;
  assign axi4liteM1_bvalid = 1'b0;
  assign axi4liteM1_bresp = 2'b00;
  
  axi4lite_2Mx1S_crossbar axi4lite_crossbar
    (
     .aclk(pcie_user_clk),                    // input wire aclk
     .aresetn(~pcie_user_reset),              // input wire aresetn
     
// in zuc_top.v (flc integration), the flc outputs only lower 20 address bits
     .s_axi_awaddr({12'h000, flc_axilite_aw_addr[19:0]}),    // input wire [31 : 0] s_axi_awaddr
     .s_axi_awprot(unconnected_axilite_aw_prot),    // input wire [2 : 0] s_axi_awprot
     .s_axi_awvalid(flc_axilite_aw_vld),  // input wire s_axi_awvalid
     .s_axi_awready(flc_axilite_aw_rdy),  // output wire s_axi_awready
     .s_axi_wdata(flc_axilite_w_data),      // input wire [31 : 0] s_axi_wdata
     .s_axi_wstrb(unconnected_axilite_w_strobe),      // input wire [3 : 0] s_axi_wstrb
     .s_axi_wvalid(flc_axilite_w_vld),    // input wire s_axi_wvalid
     .s_axi_wready(flc_axilite_w_rdy),    // output wire s_axi_wready
     .s_axi_bresp(flc_axilite_b_resp),      // output wire [1 : 0] s_axi_bresp
     .s_axi_bvalid(flc_axilite_b_vld),    // output wire s_axi_bvalid
     .s_axi_bready(flc_axilite_b_rdy),    // input wire s_axi_bready
     .s_axi_araddr({12'h000, flc_axilite_ar_addr[19:0]}),    // input wire [63 : 0] s_axi_araddr
     .s_axi_arprot(unconnected_axilite_ar_prot),    // input wire [2 : 0] s_axi_arprot
     .s_axi_arvalid(flc_axilite_ar_vld),  // input wire s_axi_arvalid
     .s_axi_arready(flc_axilite_ar_rdy),  // output wire s_axi_arready
     .s_axi_rdata(flc_axilite_r_data),      // output wire [31 : 0] s_axi_rdata
     .s_axi_rresp(unconnected_axilite_r_resp),      // output wire [1 : 0] s_axi_rresp
     .s_axi_rvalid(flc_axilite_r_vld),    // output wire s_axi_rvalid
     .s_axi_rready(flc_axilite_r_rdy),    // input wire s_axi_rready

     .m_axi_awaddr({axi4liteM1_awaddr,axi4liteM0_awaddr}),    // output wire [63 : 0] m_axi_awaddr
     .m_axi_awprot({axi4liteM1_awprot,axi4liteM0_awprot}),    // output wire [5 : 0] m_axi_awprot
     .m_axi_awvalid({axi4liteM1_awvalid,axi4liteM0_awvalid}),  // output wire [1 : 0] m_axi_awvalid
     .m_axi_awready({axi4liteM1_awready,axi4liteM0_awready}),  // input wire [1 : 0] m_axi_awready
     .m_axi_wdata({axi4liteM1_wdata,axi4liteM0_wdata}),      // output wire [63 : 0] m_axi_wdata
     .m_axi_wstrb({axi4liteM1_wstrb,axi4liteM0_wstrb}),      // output wire [7 : 0] m_axi_wstrb
     .m_axi_wvalid({axi4liteM1_wvalid,axi4liteM0_wvalid}),    // output wire [1 : 0] m_axi_wvalid
     .m_axi_wready({axi4liteM1_wready,axi4liteM0_wready}),    // input wire [1 : 0] m_axi_wready
     .m_axi_bresp({axi4liteM1_bresp,axi4liteM0_bresp}),      // input wire [3 : 0] m_axi_bresp
     .m_axi_bvalid({axi4liteM1_bvalid,axi4liteM0_bvalid}),    // input wire [1 : 0] m_axi_bvalid
     .m_axi_bready({axi4liteM1_bready,axi4liteM0_bready}),    // output wire [1 : 0] m_axi_bready
     .m_axi_araddr({axi4liteM1_araddr,axi4liteM0_araddr}),    // output wire [63 : 0] m_axi_araddr
     .m_axi_arprot({axi4liteM1_arprot,axi4liteM0_arprot}),    // output wire [5 : 0] m_axi_arprot
     .m_axi_arvalid({axi4liteM1_arvalid,axi4liteM0_arvalid}),  // output wire [1 : 0] m_axi_arvalid
     .m_axi_arready({axi4liteM1_arready,axi4liteM0_arready}),  // input wire [1 : 0] m_axi_arready
     .m_axi_rdata({axi4liteM1_rdata,axi4liteM0_rdata}),      // input wire [63 : 0] m_axi_rdata
     .m_axi_rresp({axi4liteM1_rresp,axi4liteM0_rresp}),      // input wire [3 : 0] m_axi_rresp
     .m_axi_rvalid({axi4liteM1_rvalid,axi4liteM0_rvalid}),    // input wire [1 : 0] m_axi_rvalid
     .m_axi_rready({axi4liteM1_rready,axi4liteM0_rready})    // output wire [1 : 0] m_axi_rready
     );
  

  // ==========================================================================
  // pci2sbu & sbu2pci sampling fifos
  // ==========================================================================
  // These fifos are located at the flc clk domain
  // The fifos are read via axi4lite
  //
  // Sampling enable window and buffers reset are generated inside the zuc_afu, then synchronized to mlx2sbu_clk
  // Sampling continues as long as the enable window is set
  
  // Sampling fifos control: enable & reset originate in zuc_afu, and should be synched to flc clock
  // For synch purpose, a dual clock fifo is used, with fifo wren & rden continuously active
  // Assuming the actual flc to afu clock freq ratio is always greater than 1 (i.e: 250 to 200),
  // then it is guaranteed that the read rate in the following synch fifo will always be greater than the write rate.
  // Keeping this ratio is important to avoid pci_sample_fifos_reset signal too long
  wire 	       flc_pci2sbu_sample_enable;
  wire 	       flc_sbu2pci_sample_enable;
  wire 	       flc_sample_buffers_reset;
  wire 	       unconnected_valid, unconnected_full, unconnected_empty, unconnected1;
  reg 	       sampling_fifos_ctrl_wren;
  reg 	       sampling_fifos_ctrl_rden;

  wire [511:0] pci2sbu_sample_data;
  wire 	       pci2sbu_sample_valid;
  wire 	       pci2sbu_sample_ready;
  wire 	       pci2sbu_sample_eom;
  wire 	       pci2sbu_sample_tlast;
  wire 	       pci2sbu_sample_arready;
  wire 	       pci2sbu_sample_rvalid;
  wire [1:0]   pci2sbu_sample_rresp;
  wire [31:0]  pci2sbu_sample_rdata;

  wire [511:0] sbu2pci_sample_data;
  wire 	       sbu2pci_sample_valid;
  wire 	       sbu2pci_sample_ready;
  wire 	       sbu2pci_sample_eom;
  wire 	       sbu2pci_sample_tlast;
  wire 	       sbu2pci_sample_arready;
  wire 	       sbu2pci_sample_rvalid;
  wire [1:0]   sbu2pci_sample_rresp;
  wire [31:0]  sbu2pci_sample_rdata;
  reg 	       axi4liteM1_timeout_rvalid;
  reg [7:0]    axi4liteM1_timeout_counter;
  reg 	       axi4liteM1_timeout_count_window;

// Wire the sampled bus into the appropriate sampler:
  assign pci2sbu_sample_data = flc2usr_dm_p0_tdata;
  assign pci2sbu_sample_valid = flc2usr_dm_p0_tvalid;
  assign pci2sbu_sample_ready = flc2usr_dm_p0_tready;
  assign pci2sbu_sample_eom = flc2usr_dm_p0_tuser[39];
  assign pci2sbu_sample_tlast = flc2usr_dm_p0_tlast;
  assign sbu2pci_sample_data = usr2flc_dm_p0_tdata;
  assign sbu2pci_sample_valid = usr2flc_dm_p0_tvalid;
  assign sbu2pci_sample_ready = usr2flc_dm_p0_tready;
  assign sbu2pci_sample_eom = usr2flc_dm_p0_tuser[39];
  assign sbu2pci_sample_tlast = usr2flc_dm_p0_tlast;

  assign  axi4liteM1_arready = pci2sbu_sample_arready && sbu2pci_sample_arready;
  assign  axi4liteM1_rvalid = pci2sbu_sample_rvalid || sbu2pci_sample_rvalid || axi4liteM1_timeout_rvalid;
  assign  axi4liteM1_rresp = pci2sbu_sample_rvalid ? pci2sbu_sample_rresp :
			     sbu2pci_sample_rvalid ? sbu2pci_sample_rresp :
			     axi4liteM1_timeout_rvalid ? 2'b00 : 
			     2'b00;
  assign  axi4liteM1_rdata = pci2sbu_sample_rvalid ? pci2sbu_sample_rdata :
			     sbu2pci_sample_rvalid ? sbu2pci_sample_rdata :
			     axi4liteM1_timeout_rvalid ? 32'hdeadf00d : 
			     32'hdeadf00d;

  // axi4liteM1 read timeout:
  // In case a read cycle is not responsed withing AXILITE_TIMEOUT clocks, this mechanism will respond instead.
  always @(posedge pcie_user_clk) begin
    if (pcie_user_reset)
      begin
	axi4liteM1_timeout_rvalid <= 1'b0;
	axi4liteM1_timeout_counter <= 8'h00;
	axi4liteM1_timeout_count_window <= 1'b0;
      end
    else
      begin
	if (axi4liteM1_arvalid && axi4liteM1_arready)
	  begin
	    axi4liteM1_timeout_counter <= AXILITE_TIMEOUT;
	    axi4liteM1_timeout_count_window <= 1'b1;
	  end

	if (axi4liteM1_timeout_count_window)
	  begin
	    if (axi4liteM1_timeout_counter > 8'h00)
	      axi4liteM1_timeout_counter <= axi4liteM1_timeout_counter - 8'h01;
	    else
	      begin
		axi4liteM1_timeout_rvalid <= 1'b1;
		axi4liteM1_timeout_counter <= 8'h00;
		axi4liteM1_timeout_count_window <= 1'b0;
	      end
	  end
	
	if (axi4liteM1_rvalid && axi4liteM1_rready)
	  begin
	    axi4liteM1_timeout_counter <= 8'h00;
	    axi4liteM1_timeout_rvalid <= 1'b0;
	  end
      end
  end


  always @(posedge zuc_clk) begin
    if (zuc_reset)
      begin
	sampling_fifos_ctrl_wren <= 1'b1;
	sampling_fifos_ctrl_rden <= 1'b1;
      end
  end
  
fifo_16x4b_dual_clock sampling_fifos_ctrl
  (
   .rst(zuc_reset),
   .wr_clk(zuc_clk),
   .rd_clk(pcie_user_clk),
   .din({1'b0, flc_pci_sample_enable, flc_pci_sample_soft_reset}),  // input wire [3 : 0]
   .wr_en(sampling_fifos_ctrl_wren),                        // input wire wr_en
   .rd_en(sampling_fifos_ctrl_rden),                        // input wire rd_en
   .dout({unconnected1, flc_sbu2pci_sample_enable, flc_pci2sbu_sample_enable, flc_sample_buffers_reset}),      // output wire [3 : 0]
   .full(unconnected_full),
   .empty(unconnected_empty),
   .valid(unconnected_valid)
   );


`ifdef FLC_PCI2SBU_SAMPLE_EN
// ZUC 512b axi4stream sampling buffers
zuc_sample_buf flc_pci2sbu_sample_buffer
  (
   .sample_clk(pcie_user_clk),
   .sample_reset(pcie_user_reset),
   .sample_sw_reset(flc_sample_buffers_reset),
   .sample_enable(flc_pci2sbu_sample_enable),
   .sample_tdata(pci2sbu_sample_data),
   .sample_valid(pci2sbu_sample_valid),
   .sample_ready(pci2sbu_sample_ready),
   .sample_eom(pci2sbu_sample_eom),
   .sample_tlast(pci2sbu_sample_tlast),
   .axi4lite_araddr_base(FLC_CLK_PCI2SBU),
   .axi4lite_araddr(axi4liteM1_araddr),
   .axi4lite_arvalid(axi4liteM1_arvalid),
   .axi4lite_arready(pci2sbu_sample_arready),
   .axi4lite_rready(axi4liteM1_rready),
   .axi4lite_rvalid(pci2sbu_sample_rvalid),
   .axi4lite_rresp(pci2sbu_sample_rresp),
   .axi4lite_rdata(pci2sbu_sample_rdata)
   );
`endif //  `ifdef FLC_PCI2SBU_SAMPLE_EN

`ifndef FLC_PCI2SBU_SAMPLE_EN
  assign pci2sbu_sample_rvalid = 1'b0;
  assign pci2sbu_sample_arready = 1'b1;
`endif

  
`ifdef FLC_SBU2PCI_SAMPLE_EN
zuc_sample_buf flc_sbu2pci_sample_buffer
  (
   .sample_clk(pcie_user_clk),
   .sample_reset(pcie_user_reset),
   .sample_sw_reset(flc_sample_buffers_reset),
   .sample_enable(flc_sbu2pci_sample_enable),
   .sample_tdata(sbu2pci_sample_data),
   .sample_valid(sbu2pci_sample_valid),
   .sample_ready(sbu2pci_sample_ready),
   .sample_eom(sbu2pci_sample_eom),
   .sample_tlast(sbu2pci_sample_tlast),
   .axi4lite_araddr_base(FLC_CLK_SBU2PCI),
   .axi4lite_araddr(axi4liteM1_araddr),
   .axi4lite_arvalid(axi4liteM1_arvalid),
   .axi4lite_arready(sbu2pci_sample_arready),
   .axi4lite_rready(axi4liteM1_rready),
   .axi4lite_rvalid(sbu2pci_sample_rvalid),
   .axi4lite_rresp(sbu2pci_sample_rresp),
   .axi4lite_rdata(sbu2pci_sample_rdata)
   );
`endif  

`ifndef FLC_SBU2PCI_SAMPLE_EN
  assign sbu2pci_sample_rvalid = 1'b0;
  assign sbu2pci_sample_arready = 1'b1;
`endif  

endmodule
