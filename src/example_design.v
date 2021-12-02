/*
 * Copyright (c) 2021 Gabi Malka.
 * Licensed under the 2-clause BSD license, see LICENSE for details.
 * SPDX-License-Identifier: BSD-2-Clause
 */
`define TWO_SLICES
`define AXI4LITE_IF


module example_design
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

`ifdef TWO_SLICES
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
`endif


`ifdef AXI4LITE_IF
  // External I/F (Axi4Lite Master)
  wire   [ 66:0]                       m_axi4lite_aw                      ;
  wire   [ 63:0]                       m_axi4lite_aw__addr                ;
  wire   [ 2:0]                        m_axi4lite_aw__prot                ;
  wire                                 m_axi4lite_aw__vld                 ;
  wire                                 m_axi4lite_aw__rdy                 ;
  wire   [ 35:0]                       m_axi4lite_w                       ;
  wire   [ 31:0]                       m_axi4lite_w__data                 ;
  wire   [  3:0]                       m_axi4lite_w__strobe               ;
  wire                                 m_axi4lite_w__vld                  ;
  wire                                 m_axi4lite_w__rdy                  ;
  wire   [  1:0]                       m_axi4lite_b                       ;
  wire   [  1:0]                       m_axi4lite_b__resp                 ;
  wire                                 m_axi4lite_b__vld                  ;
  wire                                 m_axi4lite_b__rdy                  ;
  wire   [ 66:0]                       m_axi4lite_ar                      ;
  wire   [ 63:0]                       m_axi4lite_ar__addr                ;
  wire   [ 2:0]                        m_axi4lite_ar__prot                ;
  wire                                 m_axi4lite_ar__vld                 ;
  wire                                 m_axi4lite_ar__rdy                 ;
  wire   [ 33:0]                       m_axi4lite_r                       ;
  wire   [ 31:0]                       m_axi4lite_r__data                 ;
  wire   [  1:0]                       m_axi4lite_r__resp                 ;
  wire                                 m_axi4lite_r__vld                  ;
  wire                                 m_axi4lite_r__rdy                  ;

`endif

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

  `ifdef AXI4LITE_IF
    // External GW (Client)
    .m_axi4lite_aw                   ( m_axi4lite_aw                     ),
    .m_axi4lite_aw__vld              ( m_axi4lite_aw__vld                ),
    .m_axi4lite_aw__rdy              ( m_axi4lite_aw__rdy                ),
    .m_axi4lite_w                    ( m_axi4lite_w                      ),
    .m_axi4lite_w__vld               ( m_axi4lite_w__vld                 ),
    .m_axi4lite_w__rdy               ( m_axi4lite_w__rdy                 ),
    .m_axi4lite_b                    ( m_axi4lite_b                      ),
    .m_axi4lite_b__vld               ( m_axi4lite_b__vld                 ),
    .m_axi4lite_b__rdy               ( m_axi4lite_b__rdy                 ),
    .m_axi4lite_ar                   ( m_axi4lite_ar                     ),
    .m_axi4lite_ar__vld              ( m_axi4lite_ar__vld                ),
    .m_axi4lite_ar__rdy              ( m_axi4lite_ar__rdy                ),
    .m_axi4lite_r                    ( m_axi4lite_r                      ),
    .m_axi4lite_r__vld               ( m_axi4lite_r__vld                 ),
    .m_axi4lite_r__rdy               ( m_axi4lite_r__rdy                 ),
  `endif

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
  // FlexConnect Instantiation
  //

  wire   [ 71:0]                       flc2usr_dm_p0_tuser_q0             ;
  assign flc2usr_dm_p0_tuser_q0 =    { flc2usr_dm_p0_tuser[71:16]         ,
	                               15'b0                              ,
	                               flc2usr_dm_p0_tuser[56]           };

  flc_user_fifo flc_user_fifo_p0
  (
    .s_aclk                          ( pcie_user_clk                     ),
    .s_aresetn                       ( ~pcie_user_reset                  ),
    .s_axis_tvalid                   ( flc2usr_dm_p0_tvalid              ),
    .s_axis_tready                   ( flc2usr_dm_p0_tready              ),
    .s_axis_tdata                    ( flc2usr_dm_p0_tdata               ),
    .s_axis_tkeep                    ( flc2usr_dm_p0_tkeep               ),
    .s_axis_tlast                    ( flc2usr_dm_p0_tlast               ),
    .s_axis_tuser                    ( flc2usr_dm_p0_tuser_q0            ),
    .m_axis_tvalid                   ( usr2flc_dm_p0_tvalid              ),
    .m_axis_tready                   ( usr2flc_dm_p0_tready              ),
    .m_axis_tdata                    ( usr2flc_dm_p0_tdata               ),
    .m_axis_tkeep                    ( usr2flc_dm_p0_tkeep               ),
    .m_axis_tlast                    ( usr2flc_dm_p0_tlast               ),
    .m_axis_tuser                    ( usr2flc_dm_p0_tuser               ) 
  );

  `ifdef TWO_SLICES
    wire   [ 71:0]                       flc2usr_dm_p1_tuser_q0           ;
    assign flc2usr_dm_p1_tuser_q0 =    { flc2usr_dm_p1_tuser[71:16]       ,
  	                               15'b0                              ,
  	                               flc2usr_dm_p1_tuser[56]           };
  
    flc_user_fifo flc_user_fifo_p1
    (
      .s_aclk                        ( pcie_user_clk                     ),
      .s_aresetn                     ( ~pcie_user_reset                  ),
      .s_axis_tvalid                 ( flc2usr_dm_p1_tvalid              ),
      .s_axis_tready                 ( flc2usr_dm_p1_tready              ),
      .s_axis_tdata                  ( flc2usr_dm_p1_tdata               ),
      .s_axis_tkeep                  ( flc2usr_dm_p1_tkeep               ),
      .s_axis_tlast                  ( flc2usr_dm_p1_tlast               ),
      .s_axis_tuser                  ( flc2usr_dm_p1_tuser_q0            ),
      .m_axis_tvalid                 ( usr2flc_dm_p1_tvalid              ),
      .m_axis_tready                 ( usr2flc_dm_p1_tready              ),
      .m_axis_tdata                  ( usr2flc_dm_p1_tdata               ),
      .m_axis_tkeep                  ( usr2flc_dm_p1_tkeep               ),
      .m_axis_tlast                  ( usr2flc_dm_p1_tlast               ),
      .m_axis_tuser                  ( usr2flc_dm_p1_tuser               ) 
    );
  `endif
 
  `ifdef AXI4LITE_IF
  //
  // External Memory for FLC GW
  //
  wire         unconnected_m_axi4lite_aw_addr                             ;
  wire         unconnected_m_axi4lite_ar_addr                             ;
  wire         unconnected_m_axi4lite_aw_prot                             ;
  wire         unconnected_m_axi4lite_ar_prot                             ;

  assign       m_axi4lite_aw__addr   = m_axi4lite_aw                      ;
  assign       m_axi4lite_aw__prot   = m_axi4lite_aw[66:64]               ;
  assign       m_axi4lite_w__data    = m_axi4lite_w                       ;
  assign       m_axi4lite_w__strobe  = m_axi4lite_w[35:32]                ;
  assign       m_axi4lite_ar__addr   = m_axi4lite_ar                      ;
  assign       m_axi4lite_ar__prot   = m_axi4lite_ar[66:64]               ;

  assign       m_axi4lite_b[1:0]     = m_axi4lite_b__resp                 ;
  assign       m_axi4lite_r[31:0]    = m_axi4lite_r__data                 ;
  assign       m_axi4lite_r[33:32]   = m_axi4lite_r__resp                 ;
  assign       unconnected_aw_addr   = |{1'b1, m_axi4lite_aw__addr[63:32]};
  assign       unconnected_ar_addr   = |{1'b1, m_axi4lite_ar__addr[63:32]};

  axi4lite_mem_1024x32 axi4lite_mem_1024x32(
    .rsta_busy                       (                                   ),
    .rstb_busy                       (                                   ),
    .s_aclk                          ( pcie_user_clk                     ),
    .s_aresetn                       ( ~pcie_user_reset                  ),
    .s_axi_awaddr                    ( m_axi4lite_aw__addr[31:0]         ),
    .s_axi_awvalid                   ( m_axi4lite_aw__vld                ),
    .s_axi_awready                   ( m_axi4lite_aw__rdy                ),
    .s_axi_wdata                     ( m_axi4lite_w__data                ),
    .s_axi_wstrb                     ( m_axi4lite_w__strobe              ),
    .s_axi_wvalid                    ( m_axi4lite_w__vld                 ),
    .s_axi_wready                    ( m_axi4lite_w__rdy                 ),
    .s_axi_bresp                     ( m_axi4lite_b__resp                ),
    .s_axi_bvalid                    ( m_axi4lite_b__vld                 ),
    .s_axi_bready                    ( m_axi4lite_b__rdy                 ),
    .s_axi_araddr                    ( m_axi4lite_ar__addr[31:0]         ),
    .s_axi_arvalid                   ( m_axi4lite_ar__vld                ),
    .s_axi_arready                   ( m_axi4lite_ar__rdy                ),
    .s_axi_rdata                     ( m_axi4lite_r__data                ),
    .s_axi_rresp                     ( m_axi4lite_r__resp                ),
    .s_axi_rvalid                    ( m_axi4lite_r__vld                 ),
    .s_axi_rready                    ( m_axi4lite_r__rdy                 ) 
  );
`endif


endmodule
