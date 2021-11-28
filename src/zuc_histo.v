// ZUC histogram module.
module zuc_histo (
		 input wire 	    hist_clk,
		 input wire 	    hist_reset,
		 input wire [2:0]   hist_id,
                 input wire 	    hist_enable,           // Update specific chid[bucket], depending on hist_value
                 input wire 	    hist_event,           // Update specific chid[bucket], depending on hist_value
                 input wire [3:0]   hist_event_chid,      // Associated chid for hist_update and hist_clear ops
                 input wire [15:0]  hist_event_value,     // Associated value for hist_update op
                 input wire 	    hist_clear,           // Clead chid[*] buckets
                 input wire [1:0]   hist_clear_op,      // Associated chid for hist_update and hist_clear ops
                 input wire [3:0]   hist_clear_chid,       // Clear all hist_table
                 input wire [2:0]   hist_clear_array,       // Clear all hist_table
                 input wire [7:0]   hist_adrs,            // hist_table port b address[7:0] = {chid[3:0], bucket_num[3:0]}
                 output wire [31:0] hist_dout             // hist table port b data
                );

`include "zuc_params.v"

  // Histogram State Machine
  localparam [2:0]
    HIST_IDLE       = 3'b000,
    HIST_CLEAR      = 3'b001,
    HIST_READ_WAIT1 = 3'b010,
    HIST_READ_WAIT2 = 3'b011,
    HIST_READ       = 3'b100,
    HIST_WRITE      = 3'b101;

// Set the bucket number to be updated:
  reg [3:0] 			    bucket_num;

  reg 				    bucket_wren;
  reg [9:0] 			    bucket_adrs;
  reg [31:0] 			    bucket_din;
  wire [31:0] 			    bucket_dout;

  reg [9:0] 			    bucket_clear_end;
  reg 				    hist_reset_array;
  reg 				    hist_readyQ;
  reg 				    clear_chidQ;
  reg 				    clear_allQ;
  reg 				    clear_all_start;
  reg 				    clear_chid_start;
  
  wire hist_ready;
  assign hist_ready = hist_readyQ;

  wire event_update;
  wire [3:0] event_chid;
  wire [15:0] event_size;
//  reg 	      hist_event_clear_chid;
//  reg [3:0]   hist_event_clear_chid_num;
//  reg 	      hist_event_clear_array;
//  reg [2:0]   hist_event_clear_array_num;
//  wire 	      hist_event_clear_pending;
//  wire 	      hist_event_clear_done;

//  assign  hist_event_clear_pending = hist_event_clear_chid + hist_event_clear_array;
//  assign  hist_event_chid = hist_event_clear_chid ? hist_event_clear_chid_num : hist_event_update_chid_num ;
  
  // updates_fifo updates fifo:
  wire [19:0] events_fifo_din;
  reg 	      events_fifo_wren;
  reg 	      events_fifo_rden;
  wire [19:0] events_fifo_dout;
  wire 	      events_fifo_full;
  wire 	      events_fifo_empty;
  wire 	      events_fifo_valid;
  wire [5:0]  events_fifo_data_count;
  wire 	      events_fifo_wr_rst_busy;
  wire 	      events_fifo_rd_rst_busy;

  reg 	      clear_chid;
  reg [3:0]   clear_chid_num;
  reg 	      clear_all;
  
  always @(posedge hist_clk) begin
    if (hist_reset)
      begin
 	clear_chid <= 1'b0;
 	clear_all <= 1'b0;
      end
    else
      begin
	// Check whether any clear operation related to this histo array 
	if (hist_clear)
	  // hist_clear is a one clock event, so should be registered here:
	  begin
	    if ((hist_clear_op == HIST_OP_CLEAR_CHID) && (hist_clear_array == hist_id))
	      // A clear operation to specific chid within current array has been asserted
	      begin
 		clear_chid <= 1'b1;
		clear_chid_num <= hist_clear_chid;
 		clear_all <= 1'b0;
	      end
	    else if ((hist_clear_op == HIST_OP_CLEAR_ARRAY) && (hist_clear_array == hist_id) ||
		     (hist_clear_op == HIST_OP_CLEAR_ALL))
	      // A clear operation to all chids within current array has been asserted
	      begin
 		clear_chid <= 1'b0;
 		clear_all <= 1'b1;
	      end
	  end

	// the clear signals are asserted to 1 clock  only. It is sampled inside the zuc_histo module
	if (clear_chid || clear_all)
	  begin
 	    clear_chid <= 1'b0;
 	    clear_all <= 1'b0;
	  end
      end
  end

  // Register the clear op, if asserted
  // While a regitered clear op is still in progrres, do not register further clear ops.
  always @(posedge hist_clk) begin
    if (hist_reset)
      begin
	clear_chidQ  <= 1'b0;
	clear_allQ  <= 1'b0;
      end
    else
      begin
	if ((clear_chid || clear_all) && ~clear_chidQ && ~clear_allQ)
	  // hist_clear and hist_clear_all are mutex ops. Both can't be set at the same time
	  begin
 	    clear_chidQ <= clear_chid;
 	    clear_allQ <= clear_all;
	  end

	// Clear the appropriate clear*, if already being serviced
	else if (clear_chidQ && clear_chid_start)
 	    clear_chidQ <= 1'b0;
	else if (clear_allQ && clear_all_start)
 	    clear_allQ <= 1'b0;
      end
  end
  
  
  // If hist_array is enabled: Load a new update event into the events fifo
  // Note: Update events are not registered, but rather immediately loaded into the fifo.
  //       If fifo is full, then the event is lost (discarded)
  assign events_fifo_din = {hist_event_chid, hist_event_value};
  always @(posedge hist_clk) begin
    if (hist_reset || clear_all_start)
      begin
 	events_fifo_wren <= 1'b0;
      end
    else
      begin
	if (hist_enable && hist_event && ~events_fifo_full && ~events_fifo_wr_rst_busy && ~events_fifo_wren)
 	  events_fifo_wren <= 1'b1;
	else if (events_fifo_wren)
 	  events_fifo_wren <= 1'b0;
      end
  end
  
  // Events fifo, first_word_fall_through
  // Upon hist_reset or upon start of clear_all event, the fifo will be cleared as well
  // Clearing the fifo upon start of clear event:
  // 1. Erasing all previuosly captured events which have been received before the clear op.
  // 2. The fif clear signal duration is one clock
  // 3. Then, allowing new events capture, even if th events are recived  during the clear_all sequence
  fifo_32x20b events_fifo 
    (
     .clk(hist_clk),                         // input wire clk
     .srst(hist_reset || clear_all_start),   // input wire srst
     .din(events_fifo_din),                  // input wire [19 : 0] din
     .wr_en(events_fifo_wren),               // input wire wr_en
     .rd_en(events_fifo_rden),               // input wire rd_en
     .dout(events_fifo_dout),                // output wire [19 : 0] dout
     .full(events_fifo_full),                // output wire full
     .empty(events_fifo_empty),              // output wire empty
     .valid(events_fifo_valid),              // output wire valid
     .data_count(events_fifo_data_count),    // output wire [5 : 0] data_count
     .wr_rst_busy(events_fifo_wr_rst_busy),  // output wire wr_rst_busy
     .rd_rst_busy(events_fifo_rd_rst_busy)   // output wire rd_rst_busy
     );

  
  // Handling next pending event from fifo to histo_array,
  // A valid fifo output means a valid update event.
  // The fifo is read (dropped) once this event is being serviced
  // Once hist_fifo is disabled, the fifo reading will continue until emptied
  assign event_update = ~events_fifo_empty && ~events_fifo_rd_rst_busy;
  assign event_chid = events_fifo_dout[19:16];
  assign event_size = events_fifo_dout[15:0];


//  always @(posedge hist_clk) begin
//    if (hist_reset)
//      begin
// 	events_fifo_rden <= 1'b0;
//	event_update <= 1'b0;
//      end
//    else
//      begin
//	if (~events_fifo_empty && ~events_fifo_rd_rst_busy && hist_ready && ~events_fifo_rden)
//	  begin
// 	    events_fifo_rden <= 1'b1;
//	  end
//	else if (events_fifo_rden)
// 	    events_fifo_rden <= 1'b0;
//
//	if (events_fifo_valid)
//	  begin
//	    event_update <= 1'b1;
//	    event_chid <= events_fifo_dout[19:16];
//	    event_size <= events_fifo_dout[15:0];
//	  end
//	else if (event_update)
//	    event_update <= 1'b0;
//      end
//  end
  


// Find the approproate bucket_num for the given event size
  always @(*) begin
    if (event_size == 0)
      bucket_num = 0;
    else if (event_size <= SIZE_BUCKET1)
      bucket_num = 1;
    else if (event_size <= SIZE_BUCKET2)
      bucket_num = 2;
    else if (event_size <= SIZE_BUCKET3)
      bucket_num = 3;
    else if (event_size <= SIZE_BUCKET4)
      bucket_num = 4;
    else if (event_size <= SIZE_BUCKET5)
      bucket_num = 5;
    else if (event_size <= SIZE_BUCKET6)
      bucket_num = 6;
    else if (event_size <= SIZE_BUCKET7)
      bucket_num = 7;
    else if (event_size <= SIZE_BUCKET8)
      bucket_num = 8;
    else if (event_size <= SIZE_BUCKET9)
      bucket_num = 9;
    else
      // hist_value is geater than 9K payload:
      bucket_num = 10;
  end // always @ begin
  
  // histo_array state machine
  reg [2:0] 			    hist_nstate;
  reg 				    hist_resetQ;

  always @(posedge hist_clk) begin
    if (hist_reset) begin
      hist_nstate <= HIST_IDLE;
      bucket_clear_end <= 10'h000;
      hist_resetQ <= hist_reset;   
      hist_readyQ <= 1'b0;   
      hist_reset_array <= 1'b0;
      bucket_adrs <= 10'h000;      
      bucket_wren <= 1'b0;
      clear_all_start <= 1'b0;
      events_fifo_rden <= 1'b0;
    end
    else begin
      if (~hist_reset && hist_resetQ)
	// hist_reset deassered (zuc afu reset ended): clear all buckets in hist_array
	begin
	  hist_reset_array <= 1'b1;
	  hist_resetQ <= 1'b0;   
	end
      
      case (hist_nstate)
	HIST_IDLE:
	  begin
	    bucket_din <= 32'h00000000;
	    hist_readyQ <= 1'b1;   

	    if (clear_chidQ) // Clear specified chid buckets
	      begin
		bucket_adrs <= {2'b00, clear_chid_num, 4'h0};
		bucket_clear_end <= {2'b00, clear_chid_num, 4'hf};
		bucket_wren <= 1'b1;
		hist_readyQ <= 1'b0;   
		clear_chid_start <= 1'b1;
		hist_nstate <= HIST_CLEAR;
	      end
	    else if (clear_allQ || hist_reset_array)
	      begin
		bucket_adrs <= {2'b00, 8'h0};
		bucket_clear_end <= 10'h0ff;
		bucket_wren <= 1'b1;
		hist_readyQ <= 1'b0;   
		clear_all_start <= clear_allQ;
		hist_nstate <= HIST_CLEAR;
	      end
	    else if (event_update)
	      begin
		// Read the desired bucket to be modified
		bucket_adrs <= {2'b00, event_chid, bucket_num};
		hist_readyQ <= 1'b0;   
 		events_fifo_rden <= 1'b1; //Current fifo output already used. Drop it !
		hist_nstate <= HIST_READ_WAIT1;
	      end
	    else
	      hist_nstate <= HIST_IDLE;
	  end
	
	HIST_CLEAR:
	  // Burst write: Clear all buckets for specified buckets, single chid or all hist_table:
	  begin

	    clear_chid_start <= 1'b0;   // Asserted to 1 clock, indicating start of a clear sequence;
	    clear_all_start <= 1'b0;
	    if (bucket_adrs == bucket_clear_end)
	      // last bucket_to_be_cleared reached !!
	      begin
		bucket_wren <= 1'b0;
		hist_reset_array <= 1'b0;
		hist_nstate <= HIST_IDLE;
	      end
	    else
	      begin
		bucket_wren <= 1'b1;
//		bucket_din <= {bucket_din[27:0], bucket_din[31:28]};
		bucket_adrs <= bucket_adrs + 10'h001; 
		hist_nstate <= HIST_CLEAR;
	      end
	  end

	HIST_READ_WAIT1:
	  // 2 clocks read latency:
	  begin
 	    events_fifo_rden <= 1'b0;
	    hist_nstate <= HIST_READ_WAIT2;
	  end

	HIST_READ_WAIT2:
	  // Wait for read to settle
	  begin
	    hist_nstate <= HIST_READ;
	  end

	HIST_READ:
	  begin
	    // Update the bucket data to be written, and goto WRITE.
	    // Max bucket value is saturated to max unsigned 32b.
	    // bucket_dout is supposed to be ready by now.
	    bucket_din <= (bucket_dout == 32'hffffffff) ? bucket_dout : bucket_dout + 32'h00000001;
	    bucket_wren <= 1'b1;
	    // The bucket_write address is unchanged: remains the same as the previously read bucket address
	    hist_nstate <= HIST_WRITE;
	  end

	HIST_WRITE:
	  // Clear all buckets for specified chid
	  begin
	    bucket_wren <= 1'b0;
	    hist_nstate <= HIST_IDLE;
	  end

	default:
	  begin
	  end
	
      endcase
    end
  end


blk_mem_DP_histo_1Kx32b hist_array
// Only lower 256 entries are used: 16 channels x 16 buckets per channel 
  (
   .clka(hist_clk),      // input wire clka
   .ena(1'b1),           // input wire ena
   .wea(bucket_wren),    // input wire [0 : 0] wea
   .addra(bucket_adrs),  // input wire [9 : 0] addra
   .dina(bucket_din),    // input wire [31 : 0] dina
   .douta(bucket_dout),  // output wire [31 : 0] douta
   .clkb(hist_clk),      // input wire clkb
   .enb(1'b1),           // input wire enb
   .web(1'b0),           // input wire [0 : 0] web
   .addrb({2'b00, hist_adrs}),    // input wire [9 : 0] addrb
   .dinb(32'h00000000),  // input wire [31 : 0] dinb
   .doutb(hist_dout)     // output wire [31 : 0] doutb
   );
  
endmodule
