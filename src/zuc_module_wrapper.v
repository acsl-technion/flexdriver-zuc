/*
 * Copyright (c) 2021 Gabi Malka.
 * Licensed under the 2-clause BSD license, see LICENSE for details.
 * SPDX-License-Identifier: BSD-2-Clause
 */
module zuc_module_wrapper (
			   input wire 	       clk,
			   input wire 	       reset,
			   input wire [3:0]    zmw_module_id,
			   input wire [2:0]    zmw_module_in_id,
			   input wire 	       zmw_module_in_valid,
			   output wire 	       zmw_in_ready,
			   input wire [511:0]  zmw_in_data,
			   input wire 	       zmw_in_last,
			   input wire 	       zmw_in_user,
			   input wire 	       zmw_in_test_mode,
			   input wire 	       zmw_in_force_modulebypass,
			   input wire 	       zmw_in_force_corebypass,
			   output wire [9:0]   zmw_fifo_in_data_count,
			   output wire 	       zmw_out_valid,
			   input wire [2:0]    zmw_module_out_id,
			   input wire 	       zmw_module_out_ready,
			   output wire [511:0] zmw_out_data,
			   output wire 	       zmw_out_last,
			   output wire 	       zmw_out_user,
			   output wire 	       zmw_out_status_valid,
			   input wire 	       zmw_out_status_ready,
			   output wire [7:0]   zmw_out_status_data,
			   output wire 	       zmw_update_regs,
			   input wire [4:0]    zmw_in_watermark,
			   output wire 	       zmw_in_watermark_met,
			   output wire [15:0]  zmw_progress,
			   output wire [31:0]  zmw_out_stats
			  );

  wire 					       zm_in_valid;
  wire 					       zm_in_ready;
  wire [511:0] 				       zm_in_data;
  wire 					       zm_in_last;
  wire 					       zm_in_user;
  wire 					       zm_out_valid;
  wire 					       zm_out_ready;
  wire [511:0]				       zm_out_data;
  wire [63:0] 				       zm_out_keep;
  wire 					       zm_out_last;
  wire 					       zm_out_user;
  wire 					       zm_status_valid;
  wire 					       zm_status_ready;
  wire [7:0] 				       zm_status_data;
  wire [9:0] 				       zm_fifo_out_data_count;
  wire [3:0] 				       unconnected4;
  wire  				       zm_module_in_valid;
  wire  				       zm_module_out_ready;
  wire  				       zm_module_out_status_ready;


  assign zm_module_in_valid = (zmw_module_in_id == zmw_module_id[2:0]) && zmw_module_in_valid ? 1'b1 : 1'b0;
  assign zm_module_out_ready = (zmw_module_out_id == zmw_module_id[2:0]) && zmw_module_out_ready ? 1'b1 : 1'b0;
  assign zm_module_out_status_ready = (zmw_module_out_id == zmw_module_id[2:0]) && zmw_out_status_ready ? 1'b1 : 1'b0;


// fifo_in, 1 x 18Kb & 7 x 36 Kb BRAMs:
  axis_512x512b_fifo zm_fifo_in (
    .s_aclk(clk),
    .s_aresetn(~reset),                       // input wire s_aresetn
    .s_axis_tvalid(zm_module_in_valid),       // input wire s_axis_tvalid
    .s_axis_tready(zmw_in_ready),             // output wire s_axis_tready
    .s_axis_tdata(zmw_in_data),               // input wire [511 : 0] s_axis_tdata // TBD: Widen fifox_in to 516 bits
    .s_axis_tlast(zmw_in_last),               // input wire s_axis_tlast
    .s_axis_tuser(zmw_in_user),               // input wire s_axis_tuser
    .m_axis_tvalid(zm_in_valid),              // output wire m_axis_tvalid
    .m_axis_tready(zm_in_ready),              // input wire m_axis_tready
    .m_axis_tdata(zm_in_data),                // output wire [511 : 0] m_axis_tdata
    .m_axis_tlast(zm_in_last),                // output wire m_axis_tlast
    .m_axis_tuser(zm_in_user),                // output wire m_axis_tuser
    .axis_data_count(zmw_fifo_in_data_count)  // output wire [9 : 0] axis_data_count
  );

  
// ZUC Module
zuc_module zm_module (
  .zm_clk(clk),
  .zm_reset(reset),
  .zm_in_valid(zm_in_valid),                  // input wire
  .zm_in_ready(zm_in_ready),                  // output wire
  .zm_in_data(zm_in_data),                    // input wire [511:0]
  .zm_in_last(zm_in_last),                    // input wire
  .zm_in_user(zm_in_user),                    // input wire
  .zm_in_test_mode(zmw_in_test_mode),         // input wire
  .zm_in_force_modulebypass(zmw_in_force_modulebypass),   // input wire
  .zm_in_force_corebypass(zmw_in_force_corebypass),   // input wire
  .fifo_in_data_count(zmw_fifo_in_data_count),
  .fifo_out_data_count(zm_fifo_out_data_count),
  .zm_out_valid(zm_out_valid),                // output wire
  .zm_out_ready(zm_out_ready),                // input wire
  .zm_out_data(zm_out_data),                  // output wire [511 : 0]
  .zm_out_keep(zm_out_keep),                  // output wire [63 : 0]
  .zm_out_last(zm_out_last),                  // output wire
  .zm_out_user(zm_out_user),                  // output wire
  .zm_out_status_valid(zm_status_valid),      // output wire
  .zm_out_status_ready(zm_status_ready),      // input wire
  .zm_out_status_data(zm_status_data),        // output wire [7:0]
  .zm_update_module_regs(zmw_update_regs),    // output wire
  .zm_in_watermark(zmw_in_watermark),         // input wire [4:0]
  .zm_in_watermark_met(zmw_in_watermark_met), // output wire
  .zm_progress(zmw_progress),                 // output wire [15:0]
  .zm_out_stats(zmw_out_stats)                // output wire [31:0]
  );

  // fifo_out, 1 x 18Kb & 7 x 36 Kb BRAMs:
axis_512x512b_fifo zm_fifo_out (
    .s_aclk(clk),
    .s_aresetn(~reset),
    .s_axis_tvalid(zm_out_valid),             // input wire s_axis_tvalid
    .s_axis_tready(zm_out_ready),             // output wire s_axis_tready
    .s_axis_tdata(zm_out_data),               // input wire [511 : 0] s_axis_tdata
    .s_axis_tlast(zm_out_last),               // input wire s_axis_tlast
    .s_axis_tuser(zm_out_user),               // input wire s_axis_tuser
    .m_axis_tvalid(zmw_out_valid),            // output wire m_axis_tvalid
    .m_axis_tready(zm_module_out_ready),      // input wire m_axis_tready
    .m_axis_tdata(zmw_out_data),              // output wire [511 : 0] m_axis_tdata
    .m_axis_tlast(zmw_out_last),              // output wire m_axis_tlast
    .m_axis_tuser(zmw_out_user),              // output wire m_axis_tuser
    .axis_data_count(zm_fifo_out_data_count)  // output wire [9 : 0] axis_data_count
  );

  // 256x8b fifo_status, Distributed RAM:
  axis_32x8b_fifo zm_fifo_status (
    .s_aclk(clk),                             // input wire s_aclk
    .s_aresetn(~reset),                       // input wire s_aresetn
    .s_axis_tvalid(zm_status_valid),          // input wire s_axis_tvalid
    .s_axis_tready(zm_status_ready),          // output wire s_axis_tready
    .s_axis_tdata(zm_status_data),            // input wire [7 : 0] s_axis_tdata
    .m_axis_tvalid(zmw_out_status_valid),     // output wire m_axis_tvalid
    .m_axis_tready(zm_module_out_status_ready), // input wire m_axis_tready
    .m_axis_tdata(zmw_out_status_data)        // output wire [7 : 0] m_axis_tdata
    );

endmodule
