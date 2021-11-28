// ZUC 512b axi4stream sampling buffer
module zuc_sample_buf (
		 input wire 	    sample_clk,
		 input wire 	    sample_reset,
		 input wire 	    sample_sw_reset,
		 input wire 	    sample_enable,
		 input wire [511:0] sample_tdata,
		 input wire 	    sample_valid,
		 input wire 	    sample_ready,
		 input wire 	    sample_eom,
		 input wire 	    sample_tlast,
                 input wire [19:0]  axi4lite_araddr_base,
                 input wire [19:0]  axi4lite_araddr,
                 input wire 	    axi4lite_arvalid,
                 output wire 	    axi4lite_arready,
                 input wire 	    axi4lite_rready,
                 output wire 	    axi4lite_rvalid,
                 output wire [1:0]  axi4lite_rresp,
                 output reg [31:0]  axi4lite_rdata             // Selected 32b out of the 512b sample
                );

`include "zuc_params.v"
  
// 512b axi4stream sampling fifo
// The fifo is read via axi4lite
//
// Sampling enable and buffer reset are generated inside the zuc_afu.
// If the sampler is located at the flc clock domain, then the sampling enable & reset are synchronized to flc clk before use.
// Sampling continues as long as the enable window is set.
  
  reg  [515:0] data_fifo_din;
  wire [515:0] data_fifo_dout;
  wire 	       data_fifo_valid;
  reg 	       data_fifo_wren, data_fifo_rden;
  wire 	       data_fifo_almost_full;
  wire 	       unconnected_almost_full;
  wire [13:0]  data_fifo_data_count;
  reg 	       sample_first;
  reg [31:0]   data_fifo_selected_dw;


// Sampling fifo control
//
// AXI4Lite address
//   'h<base>000.. 'h<base>040 - data_fifo_dout // {data_count, dout[515:0]} - 17 DW 
  
// Select the specific DW from fifo out:

  always @(*) begin
    case (axi4lite_araddr[7:2])
      16:
	begin
	  data_fifo_selected_dw <= {data_fifo_valid, 9'h000, data_fifo_data_count, 4'h0, data_fifo_dout[515:512]};
	end
      
      15:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[511:480];
	end
      
      14:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[479:448];
	end
      
      13:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[447:416];
	end
      
      12:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[415:384];
	end
      
      11:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[383:352];
	end
      
      10:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[351:320];
	end
      
      9:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[319:288];
	end
      
      8:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[287:256];
	end
      
      7:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[255:224];
	end
      
      6:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[223:192];
	end
      
      5:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[191:160];
	end
      
      4:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[159:128];
	end
      
      3:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[127:96];
	end
      
      2:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[95:64];
	end
      
      1:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[63:32];
	end
      
      0:
	begin
	  data_fifo_selected_dw <= data_fifo_dout[31:0];
	end
      
      default:
	begin
	  data_fifo_selected_dw <= 32'hdeadf00d;
	end
    endcase
  end

  reg [19:0] axi4lite_araddrQ;
  reg [1:0]  axi_state;
  reg 	     axi4lite_arready;
  reg 	     axi4lite_rvalid;
//  reg [31:0] axi4lite_fifo_rdata;
  reg [3:0]  data_fifo_drop_count;
  wire 	     fifo_lowest_dw_is_read;
  
  assign axi4lite_rresp = 2'b00;
  assign fifo_lowest_dw_is_read = axi4lite_rvalid && axi4lite_rready && (axi4lite_araddrQ == axi4lite_araddr_base); // fifo_dout lowest DW 
  
  // Wrap-around sampling scheme:
  // As the fifo capacity crossing a predefined threshold, 8 oldest lines are dropped, to make room for newer samples.
  assign data_fifo_almost_full = ({2'b00, data_fifo_data_count} >= SAMPLE_FIFO_WATERMARK) ? 1'b1 : 1'b0;  
  
  always @(posedge sample_clk) begin
    if (sample_reset || sample_sw_reset)
      begin
	data_fifo_rden <= 1'b0;
	data_fifo_wren <= 1'b0;
	axi4lite_arready <= 1'b1;
	axi4lite_rvalid <= 1'b0;
	sample_first <= 1'b1;
	data_fifo_drop_count <= 4'h0;
	axi_state <= 2'b00;
      end
    
    else
      begin
	if (axi_state == 2'b00)
	  // axi4lite read address phase
	  begin
	    if (axi4lite_arvalid && axi4lite_arready)
	      begin
		// Sampling a valid araddr, for use during the corresponding data cycle
		axi4lite_araddrQ <= axi4lite_araddr;
		// Reading an empty fifo returns 'hdeadf00d
		
		if ({axi4lite_araddr[19:8], 8'h00} == axi4lite_araddr_base) // fifo read address base
		  // fifo read addressing:
		  // a 512b line is read as 16 x 32b DW,
		  // adrs[19:0]   read_dw
		  // ===========+=====================
		  // 'h<base>00   fifo_dout[31:0]
		  // 'h<base>04   fifo_dout[63:32]
		  // ...
		  // 'h<base>3c   fifo_dout[511:480] // Current fifo line id dropped, after reading this DW
		  // 'h<base>40   {fifo_data_count, fifo_dout[515:511]}
		  begin 
		    axi4lite_arready <= 1'b0;
//		    axi4lite_rvalid <= 1'b1;
//		    axi4lite_fifo_rdata <= data_fifo_valid ? data_fifo_selected_dw : 32'hdeadf00d;
		    axi_state <= 2'b01;
		  end
	      end
	  end
	
	else if (axi_state == 2'b01)
	  // 1 clock wait for the fifo_out 512b -> 32b selector:
	  begin
	    axi4lite_rvalid <= 1'b1;
	    axi4lite_rdata <= (axi4lite_araddr[7:0] == 8'h40) ? data_fifo_selected_dw :
			      data_fifo_valid ? data_fifo_selected_dw : 32'hdeadf00d;
	    axi_state <= 2'b10; // goto rdata
	  end

	else if (axi_state == 2'b10)
	  // axi4lite read data phase
	  begin
	    if (axi4lite_rvalid && axi4lite_rready)
	      begin
		axi4lite_arready <= 1'b1;
		axi4lite_rvalid <= 1'b0;
		axi_state <= 2'b00; // goto radrs
	      end	
	  end	
	
	// The sampling fifo is read (oldest line is dropped) in two cases: 
	// 1. To implement a wrap_wround sampling window, if the fifo is almost_full, 8 oldest samples are discarded,
	//    making room for next sample
	//    almost_full is defined FIFO_SIZE - 8
	// 2. The lowest DW of a VALID line has been read,
	if (data_fifo_almost_full || (data_fifo_drop_count > 0) || fifo_lowest_dw_is_read && data_fifo_valid)
	  begin
	    data_fifo_rden <= 1'b1;

	    if (data_fifo_almost_full && (data_fifo_drop_count == 0))
	      data_fifo_drop_count <= 4'h7;
	    else if (data_fifo_drop_count > 0)
	      data_fifo_drop_count <= data_fifo_drop_count - 4'h1;
	  end
	else
	  data_fifo_rden <= 1'b0;
	
	// Sample full axi4stream line into fifo
	// fifo 'full' is ignored, since the fifo never gets full (see above)
	if (~data_fifo_wr_rst_busy && sample_enable && sample_valid && sample_ready)
	  begin
	    data_fifo_din <= {sample_eom, 1'b0, sample_first, sample_tlast, sample_tdata};
	    data_fifo_wren <= 1'b1;

	    // Update start of packet indication, towards next fifo line sampling
	    if (sample_tlast)
	      sample_first <= 1'b1;
	    else
	      sample_first <= 1'b0;
	  end

	else 
	  data_fifo_wren <= 1'b0;
      end
  end


  fifo_8Kx516b data_fifo 
    (
     .clk(sample_clk),                       // input wire clk
     .srst(sample_reset || sample_sw_reset), // input wire srst
     .din(data_fifo_din),                    // input wire [515 : 0] din
     .wr_en(data_fifo_wren),                 // input wire wr_en
     .rd_en(data_fifo_rden),                 // input wire rd_en
     .dout(data_fifo_dout),                  // output wire [515 : 0] dout
     .full(data_fifo_full),                  // output wire full
     .almost_full(unconnected_almost_full),  // output wire almost_full
     .empty(data_fifo_empty),                // output wire empty
     .almost_empty(data_fifo_almost_empty),  // output wire almost_empty
     .valid(data_fifo_valid),                // output wire valid
     .data_count(data_fifo_data_count),      // output wire [13 : 0] data_count
     .wr_rst_busy(data_fifo_wr_rst_busy),    // output wire wr_rst_busy
     .rd_rst_busy(data_fifo_rd_rst_busy)     // output wire rd_rst_busy
     );

endmodule
