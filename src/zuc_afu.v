// zuc_afu.v
// 3-May-2020
module zuc_afu(
	       clk,
	       reset,

	       afu_soft_reset,
	       pci2sbu_axi4stream_vld,
	       pci2sbu_axi4stream_rdy,
	       pci2sbu_axi4stream_tdata,
	       pci2sbu_axi4stream_tkeep,
	       pci2sbu_axi4stream_tlast,
	       pci2sbu_axi4stream_tuser, 

	       sbu2pci_axi4stream_vld,
	       sbu2pci_axi4stream_rdy,
	       sbu2pci_axi4stream_tdata,
	       sbu2pci_axi4stream_tkeep,
	       sbu2pci_axi4stream_tlast,
	       sbu2pci_axi4stream_tuser,
	       
	       axilite_aw_rdy,
	       axilite_aw_vld,
	       axilite_aw_addr,
	       axilite_aw_prot,
	       axilite_w_rdy,
	       axilite_w_vld,
	       axilite_w_data,
	       axilite_w_strobe,
	       axilite_b_rdy,
	       axilite_b_vld,
	       axilite_b_resp,
	       axilite_ar_rdy,
	       axilite_ar_vld,
	       axilite_ar_addr,
	       axilite_ar_prot,
	       axilite_r_rdy,
	       axilite_r_vld,
	       axilite_r_data,
	       axilite_r_resp,

	       fld_pci_sample_soft_reset,
	       fld_pci_sample_enable,
	       afu_events
	       );
  
  input          clk;
  input          reset;
  
  output 	 afu_soft_reset;
  output	 pci2sbu_axi4stream_rdy;
  input          pci2sbu_axi4stream_vld;
  input [511:0]  pci2sbu_axi4stream_tdata;
  input [63:0] 	 pci2sbu_axi4stream_tkeep;
  input [0:0] 	 pci2sbu_axi4stream_tlast;
  input [71:0] 	 pci2sbu_axi4stream_tuser;
  
  input          sbu2pci_axi4stream_rdy;
  output         sbu2pci_axi4stream_vld;
  output [511:0] sbu2pci_axi4stream_tdata;
  output [63:0]  sbu2pci_axi4stream_tkeep;
  output [0:0] 	 sbu2pci_axi4stream_tlast;
  output [71:0]  sbu2pci_axi4stream_tuser;
  
  output 	 axilite_aw_rdy;
  input 	 axilite_aw_vld;
  input [63:0] 	 axilite_aw_addr;
  input [2:0] 	 axilite_aw_prot;
  output 	 axilite_w_rdy;
  input 	 axilite_w_vld;
  input [31:0] 	 axilite_w_data;
  input [3:0] 	 axilite_w_strobe;
  input 	 axilite_b_rdy;
  output 	 axilite_b_vld;
  output [1:0] 	 axilite_b_resp;
  output 	 axilite_ar_rdy;
  input 	 axilite_ar_vld;
  input [63:0] 	 axilite_ar_addr;
  input [2:0] 	 axilite_ar_prot;
  input 	 axilite_r_rdy;
  output 	 axilite_r_vld;
  output [31:0]  axilite_r_data;
  output [1:0] 	 axilite_r_resp;
  output 	 fld_pci_sample_soft_reset;
  output [1:0] 	 fld_pci_sample_enable;
  output [63:0]  afu_events;

`include "zuc_params.v"

  // Limit number of zuc modules to 8
  localparam NUM_MODULES = NUMBER_OF_MODULES < 'd9 ? NUMBER_OF_MODULES : 'd8;
  
//------------------------Local axi4lite ------------------
  // ======================================================
  // AFU registers/counters and its axi4lite address mapping
  // ======================================================
  //
  // afu_ctrl0    General AFU & modules control
  //       [31] - zuc_afu reset. Writing '1 will reset zuc_afu (same as power up/hw reset)
  //       [30] - Reserved
  //       [29] - Modules Test Mode: zuc core progress dump.
  //              When set, the following core info is dumped into out_fifo.
  //              4 x 512b flits in total, following the response header:
  //              flit 1: Initial state of LFSR, S[0]-S[15], total 64 byts. LFSR ingredients order:
  //                      flit_1[511:0] = {LFSR_S[0], LFSR_S[1], ... LFSR_S[15]}
  //              flit 2: state of LFSR after initialization
  //              flit 3: First incoming message flit, as seen by the zuc_core
  //              flit 4: Last (up to) 16 Keystream words. Padded with zeros, is message length < 60Bytes 
  //                      Recall that number of keystrem words depends on opcode:  
  //                      CONF:  #keystream words == # message_payload words
  //                      INTEG: #keystream words == # message_payload words + 2  !!!
  //
  //              The order of the above 4 flits dependes on the response type:
  //              RDMA/INTEG response:
  //              1. Response header, without the MAC
  //              2. Initial state of LFSR, S[0]-S[15], total 64 byts. LFSR ingredients order:
  //              3. State of LFSR after initialization
  //              4. First incoming message flit.
  //              5. Last (up to) 16 Keystream words 
  //              6. Response header, including MAC
  //
  //              RDMA/CONF response:
  //              1. Response header
  //              2. Initial state of LFSR, S[0]-S[15], total 64 byts. LFSR ingredients order:
  //              3. State of LFSR after initialization
  //              4. First incoming message flit
  //              6. Response OBS (multiple flits, depending on message size)
  //              n. Final flit: Last (up to) 16 Keystream words 
  //
  //              Ethernet/INTEG response:
  //              1. Ethernet header
  //              2. Initial state of LFSR, S[0]-S[15], total 64 byts. LFSR ingredients order:
  //              3. State of LFSR after initialization
  //              4. First incoming message flit
  //              5. Last (up to) 16 Keystream words 
  //              6. Response header, including MAC
  //
  //              Ethernet/CONF response:
  //              1. Ethernet header
  //              2. Response header
  //              3. Initial state of LFSR, S[0]-S[15], total 64 byts. LFSR ingredients order:
  //              4. State of LFSR after initialization
  //              5. First incoming message flit
  //              6. Response OBS (multiple flits, depending on message size)
  //              n. Final flit: Last (up to) 16 Keystream words 
  //
  //       [28] - Force incoming pci2sbu_tuser[EOM].
  //              Temporarily added per Haggai's request, until EOM is implemented in FLD 
  //             
  //    [27:20] - zuc_module i [7 thru 0] enabled. Module i enable is ignored, if module i is not instantiated
  //              Default setting, 8'hff: All zuc_modules are enabled
  //    [19:18] - Force AFU/Modules Bypass
  //              00 - Normal operation
  //              01 - Force ZUC core bypass: Applicable to CONF command only.
  //                   ZUC core will respond with the exact input request payload,
  //                   rather than with the encrypted payload.	   
  //              10 - Force AFU bypass: All messages are bypased to sbu2pci, independent of the incoming message status
  //              11 - Force Module bypass: Zuc core is bypassed. Relevant only to 'good' messages which already assigned to cores
  //    [17:16] - fifo_in arbitration/selection mode:
  //              x0: fifox_in occupancy (data_count) based arbitration
  //              01: fifox_in load (zuc_cmd & message length) based arbitration
  //              11: Simple round robin between the fifox_in
  //              Default setting, cleared: fifox_in occupancy based arbitration
  //     [15:9] - Reserved
  //      [8:0] - input_buffer_watermark (buffer line == tick). Max value: 10'h1f0 (496) 
  //              The watermark is effective to all channel buffers in input buffer.
  //              channel[x] input_buffer content is not read to zuc modules, until its capacity exceeds the watermark.
  //              Default setting: 10'h000: input_buffer is read to zuc modules once it holds at least one message.
  reg [31:0]      afu_ctrl0;
  reg             afu_ctrl0_wr;

  // afu_ctrl1    Modules fifo_in watermark
  //    [31:28] - Module 7 fifo_in capacity high watermark, 32 fifo lines (2KB) per tick. Max setting: 4'hf (480 lines).
  //              The transfer from fifo7_in to zuc_core is held until this watermark is exceeded.
  //              Potential deadlock: There is insufficient free space in fifo_in for next message, and the watermark still not met.
  //              To avoind the above deadlock, the fifo hold is terminated upon meeting the watermark OR fifo_in_full
  //              fifo_in_full is asserted upon a failed atempt to write to fifo_in, due to insufficient free space. 
  //
  //              This capability is aimed for testing the zuc_cores utilization & tpt:
  //              1. To utilize all zuc_cores, there is a need to apply the messages to the cores as fast as possible.
  //              2. To eliminate the dependence on pci2sbu incoming messages rate, we accumulate into fifo_in first
  //              3. Once the watermark is exceeded, the messages are fed to the zuc cores at full speed (512b/clock). 
  //              Usage Note: This watermark is effective only once, immediateley after writing afu_ctrl1.
  //                          To reactivate, rewrite to afu_ctrl1 is required 
  //                            
  //     [27:0] - Modules 6 thru 0 fifo_in capacity high watermark.
  //              Default setting, 32'h00000000: Zero watermark to all modules fifo_in            
  reg [31:0]      afu_ctrl1;
  reg             afu_ctrl1_wr;

  // afu_ctrl2    Per channel behaviour
  //    [31:17] - Reserved
  //       [16] - Enable messages metadata on sbu2pci_data ethernet & message headers, bits [59:0]
  //              0 - No metadata. sbu2pci_data[59:0] are cleared.
  //              1 - Metadata is added. See "Internal AFU Message Header" for details
  //              Default setting, cleared: No metadata is added to headers
  //     [15:0] - message ordering mask per channel. If ctrl2[x] is set, no messages ordering for chidx.
  //              Useful in case there is a problem with messages ordering.
  //              Default setting, cleared: Message ordering is enabled for all channels 
  reg [31:0]      afu_ctrl2;
  reg             afu_ctrl2_wr;
  
  // afu_ctrl3    General afu functions
  //      [31:1] - Reserved
  //         [0] - Control whether to clear backpressure counters after read
  //               0 - Backpressure counter8 & counter9 are unaffected by axi4lite read
  //               1 - Backpressure counter8 & counter9 are cleared after axi4lite read
  //              Default setting, 32'h00000000=1: counter8 & counter9 are cleared after axi4lite read
  reg [31:0]      afu_ctrl3;
  reg             afu_ctrl3_wr;

  // afu_ctrl4     Histograms Control
  //     [31:20] - Reserved
  //     [19:12] - Histogram Arrays Enable.
  //               A histogram array will start accumulating events once it has been enabled. Disabling a histogram array will halt further events accumulation,
  //               while maintaining the array contents.
  //               [19:16] reserved
  //	           [15]    sbu2pci responses size histogram enable
  //	           [14]    pci2sbu messages size histogram enable
  //	           [13]    pci2sbu packets&EOM size histogram enable
  //	           [12]    pci2sbu packets size histogram enable
  //		   [23:20] Reserved
  //               Default: 8'h00, all histograms are disabled
  //	 [11:10] - Reserved
  //	   [9:8] - Histogram clear operation.
  //               Edge sensitive control: The selected clear operation takes effect ONLY once, and after the write operation.
  //               00 - No operation
  //               01 - Clear buckets of specified channel in specified histo_array
  //               10 - Clear buckets of all channels in the specified histo_array
  //               11 - Clear buckets of all channels in all histo_arrays
  //               Default: 2'b00, No Operation
  //         [7] - Reserved
  //       [6:4] - Histogram array select. The selected array to be cleared:
  //               Note: This selection is relevant to HISTO_CLEAR_OP==01 or HISTO_CLEAR_OP==10 operations only.
  //               000 - pci2sbu packets size histogram
  //               001 - pci2sbu packets&EOM size histogram
  //               010 - pci2sbu messages size histogram
  //               011 - sbu2pci responses size histogram
  //               1xx - Reserved
  //               Default: 3b000
  //       [3:0] - Channel ID select.The selected chid[3:0] to be cleared.
  //               Note: This selection is relevant to HISTO_CLEAR_OP==01 operation only.
  //               Default: 4'h0
  //
  reg [31:0]      afu_ctrl4;
  reg             afu_ctrl4_wr;

  // afu_ctrl5   pci2sbu & sbu2pci sampling fifos enable
  //      [31] - pci2sbu & sbu2pci sampling fifos reset
  //             Edge sensitive control: The clear operation takes effect ONLY once, and after the write operation.
  //    [30:4] - Reserved
  //     [3:0] - Sampling Enable:
  //             [3] - afu_sbu2pci sampling fifo enable
  //             [2] - afu_pci2sbu sampling fifo enable
  //             [1] - fld_sbu2pci sampling fifo enable
  //             [0] - fld_pci2sbu sampling fifo enable
  //             Default: 4'h0 - Sampling is disabled
  //
  reg [31:0]      afu_ctrl5;
  reg             afu_ctrl5_wr;

  // afu_ctrl8 & 9   Sampling trigger
  //    afu_ctrl8[31:0] - Smpling_trigger[31:0]
  //    afu_ctrl9[31:0] - Smpling_trigger[63:32]
  reg [31:0]      afu_ctrl8;
  reg [31:0]      afu_ctrl9;


  reg [31:0] 	  afu_counter0;
  reg [31:0] 	  afu_counter1;
  reg [31:0] 	  afu_counter2;
  reg [31:0] 	  afu_counter3;
  reg [31:0] 	  afu_counter4;
  reg [31:0] 	  afu_counter5;
  reg [31:0] 	  afu_counter6;
  reg [31:0] 	  afu_counter7;
  reg [32:0] 	  afu_counter8;
  reg [32:0] 	  afu_counter9;
  reg [31:0] 	  afu_scratchpad; // Scratch pad, read/write register, for axi4lite transactions testing
  reg 		  afu_counter8_read;
  reg 		  afu_counter8_cleared;
  reg 		  afu_counter9_read;
  reg 		  afu_counter9_cleared;
  reg 		  afu_reset;
  reg [7:0] 	  afu_reset_count;
  reg 		  pci_sample_reset;
  reg [7:0] 	  pci_sample_reset_count;
  wire 		  afu_pci_sample_soft_reset;
  wire 		  afu_pci2sbu_sample_enable;
  wire 		  afu_sbu2pci_sample_enable;
  wire 		  module_in_sample_enable;
  wire 		  input_buffer_sample_enable;
  reg [47:0] 	  timestamp;
  
  
  assign afu_soft_reset = afu_reset;
  assign afu_pci_sample_soft_reset = pci_sample_reset;
  assign afu_pci2sbu_sample_enable = afu_ctrl5[2];
  assign afu_sbu2pci_sample_enable = afu_ctrl5[3];
  assign input_buffer_sample_enable = afu_ctrl5[4] && sampling_window;
  assign module_in_sample_enable = afu_ctrl5[5] && sampling_window;
  assign fld_pci_sample_soft_reset = pci_sample_reset;
  assign fld_pci_sample_enable = afu_ctrl5[1:0];

localparam
  AXILITE_AFU_ADDR_WIDTH = 20;

localparam
  ADDR_AFU_CTRL0        = 20'h01000, // write only
  ADDR_AFU_CTRL1        = 20'h01004, // write only
  ADDR_AFU_CTRL2        = 20'h01008, // write only
  ADDR_AFU_CTRL3        = 20'h0100c, // write only
  ADDR_AFU_CTRL4        = 20'h01010, // write only
  ADDR_AFU_CTRL5        = 20'h01014, // write only
  ADDR_AFU_CTRL8        = 20'h01020, // write only
  ADDR_AFU_CTRL9        = 20'h01024, // write only
  ADDR_AFU_SCRATCHPAD   = 20'h01030, // write/read
  ADDR_AFU_COUNTER0     = 20'h01100, // read only
  ADDR_AFU_COUNTER1     = 20'h01104, // read only
  ADDR_AFU_COUNTER2     = 20'h01108, // read only
  ADDR_AFU_COUNTER3     = 20'h0110c, // read only
  ADDR_AFU_COUNTER4     = 20'h01110, // read only
  ADDR_AFU_COUNTER5     = 20'h01114, // read only
  ADDR_AFU_COUNTER6     = 20'h01118, // read only
  ADDR_AFU_COUNTER7     = 20'h0111c, // read only
  ADDR_AFU_COUNTER8     = 20'h01120, // read only, destructive read (cleared after read)
  ADDR_AFU_COUNTER9     = 20'h01124, // read only, destructive read (cleared after read)
  ADDR_TIMESTAMPL       = 20'h01200, // read only
  ADDR_TIMESTAMPH       = 20'h01204; // read only

localparam
  //  ADDR_AFU_HISTO_CiHjBk = 16'h2ijk; // read only. Channeli (i={0,1,2,..15}), Histogramj (j={0,1,2,3}), Bucketk (k={0,1,2,..9})
  ADDR_AFU_HISTO_BASE     = 20'h02000, // hist tables start address.
  ADDR_AFU_HISTO0_BASE    = 20'h02000, // hist_table 0 start address. 1KB=256x4B address space is assigned to each histo table  
  ADDR_AFU_HISTO1_BASE    = 20'h02400, // hist_table 1 start address
  ADDR_AFU_HISTO2_BASE    = 20'h02800, // hist_table 2 start address 
  ADDR_AFU_HISTO3_BASE    = 20'h02c00, // hist_table 3 start address 
  ADDR_AFU_HISTO4_BASE    = 20'h03000, // hist_table 4 start address 
  ADDR_AFU_HISTO5_BASE    = 20'h03400, // hist_table 5 start address 
  ADDR_AFU_HISTO6_BASE    = 20'h03800, // hist_table 6 start address 
  ADDR_AFU_HISTO7_BASE    = 20'h03c00, // hist_table 7 start address 
  ADDR_AFU_HISTO_END      = 20'h04000; // hist_table 7 end address

  localparam
  // PCI sampling buffers
  ADDR_SAMPLE_BUFFERS_BASE = AFU_CLK_PCI2SBU,                     // 20'h08000 
  ADDR_PCI2SBU_SAMPLE_BASE = AFU_CLK_PCI2SBU,                     // 20'h08000 
  ADDR_PCI2SBU_SAMPLE_END  = AFU_CLK_PCI2SBU + 20'h0100,          // 20'h08100 
  ADDR_SBU2PCI_SAMPLE_BASE = AFU_CLK_SBU2PCI,                     // 20'h08100
  ADDR_SBU2PCI_SAMPLE_END  = AFU_CLK_SBU2PCI + 20'h0100,          // 20'h08200
  ADDR_MODULE_IN_SAMPLE_BASE = AFU_CLK_MODULE_IN,                 // 20'h08200
  ADDR_MODULE_IN_SAMPLE_END  = AFU_CLK_MODULE_IN + 20'h0100,      // 20'h08300
  ADDR_INPUT_BUFFER_SAMPLE_BASE = AFU_CLK_INPUT_BUFFER,           // 20'h08300
  ADDR_INPUT_BUFFER_SAMPLE_END = AFU_CLK_INPUT_BUFFER + 20'h0100, // 20'h08400
  ADDR_SAMPLE_BUFFERS_END = AFU_CLK_INPUT_BUFFER + 20'h0100; // 20'h08400

  
  // axi4lite fsm signals
  reg [1:0] 	  axi_rstate;
  reg [1:0] 	  axi_rnext;
  reg [31:0] 	  axi_rdata;
  reg 		  axi_arready;
  wire 		  axi_aw_hs;
  wire 		  axi_w_hs;
  reg [1:0] 	  axi_wstate;
  reg [1:0] 	  axi_wnext;
  reg [AXILITE_AFU_ADDR_WIDTH-1 : 0] axi_waddr;
  wire [AXILITE_AFU_ADDR_WIDTH-1 : 0] axi_raddr;
  
  localparam
    WRIDLE                     = 2'd0,
    WRDATA                     = 2'd1,
    WRRESP                     = 2'd2,
    RDIDLE                     = 2'd0,
    RDTABLEWAIT1               = 2'd1,
    RDTABLEWAIT2               = 2'd2,
    RDDATA                     = 2'd3;
  
  // Histograms-AFU interface 
  wire 	       hist_pci2sbu_packet_enable;
  reg 	       hist_pci2sbu_packet_event;
  reg [15:0]   hist_pci2sbu_packet_event_size;
  reg [3:0]    hist_pci2sbu_packet_event_chid;
  wire [31:0]  hist_pci2sbu_packet_dout;

  wire	       hist_pci2sbu_eompacket_enable;
  reg 	       hist_pci2sbu_eompacket_event;
  reg [15:0]   hist_pci2sbu_eompacket_event_size;
  reg [3:0]    hist_pci2sbu_eompacket_event_chid;
  wire [31:0]  hist_pci2sbu_eompacket_dout;

  wire	       hist_pci2sbu_message_enable;
  reg 	       hist_pci2sbu_message_event;
  reg [15:0]   hist_pci2sbu_message_event_size;
  reg [3:0]    hist_pci2sbu_message_event_chid;
  wire [31:0]  hist_pci2sbu_message_dout;

  wire	       hist_sbu2pci_response_enable;
  reg 	       hist_sbu2pci_response_event;
  reg [15:0]   hist_sbu2pci_response_event_size;
  reg [3:0]    hist_sbu2pci_response_event_chid;
  wire [31:0]  hist_sbu2pci_response_dout;

  wire 	       hist_clear = afu_ctrl4_wr;
  wire [1:0]   hist_clear_op =    afu_ctrl4[9:8];
  wire [2:0]   hist_clear_array = afu_ctrl4[6:4];
  wire [3:0]   hist_clear_chid =  afu_ctrl4[3:0];
  
  assign hist_pci2sbu_packet_enable = afu_ctrl5[8];
  assign hist_pci2sbu_eompacket_enable = afu_ctrl5[9];
  assign hist_pci2sbu_message_enable = afu_ctrl5[10];
  assign hist_sbu2pci_response_enable = afu_ctrl5[11];
    

  // axi4lite read fsm
  assign axilite_ar_rdy = axi_arready;
  assign axilite_r_data   = axi_rdata;
  assign axilite_r_resp   = 2'b00;  // OKAY
  assign axilite_r_vld  = (axi_rstate == RDDATA);
  assign axi_raddr = {1'b0, axilite_ar_addr[AXILITE_AFU_ADDR_WIDTH-2:0]}; // address MSB is forced to 0, to enfoce a positive integer 
  assign axi_rd_table = ((axi_raddr >= ADDR_AFU_HISTO_BASE) && (axi_raddr < ADDR_AFU_HISTO_END) ||
			(axi_raddr >= ADDR_SAMPLE_BUFFERS_BASE) && (axi_raddr < ADDR_SAMPLE_BUFFERS_END))   ? 1'b1 : 1'b0;
  
  // rstate
  always @(posedge clk) begin
    if (reset) begin
      axi_rstate <= RDIDLE;
    end
    else begin
      axi_rstate <= axi_rnext;
    end
  end
  
  // rnext
  always @(*) begin
    case (axi_rstate)
      RDIDLE:
	begin
	  axi_arready = 1'b0;
          if (axilite_ar_vld && ~axi_rd_table)
	    begin
	      axi_arready = 1'b1;
              axi_rnext = RDDATA;
	    end  
	  else if (axilite_ar_vld && axi_rd_table)
            axi_rnext = RDTABLEWAIT1;
          else
            axi_rnext = RDIDLE;
	end // case: RDIDLE
      
      RDTABLEWAIT1:
	// Wait 2 clocks if the histograms arrays are read (BRAM read latency==2)
        axi_rnext = RDTABLEWAIT2;

      RDTABLEWAIT2:
	begin
	  axi_arready = 1'b1;
          axi_rnext = RDDATA;
	end
      
      RDDATA:
	begin
	  axi_arready = 1'b0;
          if (axilite_r_rdy && axilite_r_vld)
            axi_rnext = RDIDLE;
          else
            axi_rnext = RDDATA;
	end
      
      default:
        axi_rnext = RDIDLE;
    endcase
  end
  
  // rdata
  always @(posedge clk) begin
    if (reset)
      begin
	afu_counter8_read <= 1'b0;
	afu_counter9_read <= 1'b0;
      end
    else if (axilite_ar_rdy & axilite_ar_vld)
      begin
	axi_rdata <= 32'hdeadf00d;
	if (axi_raddr == ADDR_AFU_COUNTER0)
	  axi_rdata <= afu_counter0;
	if (axi_raddr == ADDR_AFU_COUNTER1)
	  axi_rdata <= afu_counter1;
	if (axi_raddr == ADDR_AFU_COUNTER2)
	  axi_rdata <= afu_counter2;
	if (axi_raddr == ADDR_AFU_COUNTER3)
	  axi_rdata <= afu_counter3;
	if (axi_raddr == ADDR_AFU_COUNTER4)
	  axi_rdata <= afu_counter4;
	if (axi_raddr == ADDR_AFU_COUNTER5)
	  axi_rdata <= afu_counter5;
	if (axi_raddr == ADDR_AFU_COUNTER6)
	  axi_rdata <= afu_counter6;
	if (axi_raddr == ADDR_AFU_COUNTER7)
	  axi_rdata <= afu_counter7;
	if (axi_raddr == ADDR_AFU_COUNTER8)
	  begin
	    axi_rdata <= afu_counter8[31:0];
	    // counter8_read indication is used to clear counter8 upon axi4lite read.
	    // Yet, this capability is enabled only if ctrl3[0] is set.
	    // If ctrl3[0] is cleared, then counter8 is not affected by the axi4lite read
	    afu_counter8_read <= afu_ctrl3[0] ? 1'b1 : 1'b0;
	  end
	if (axi_raddr == ADDR_AFU_COUNTER9)
	  begin
	    axi_rdata <= afu_counter9[31:0];
	    afu_counter9_read <= afu_ctrl3[0] ? 1'b1 : 1'b0;
	  end
	if (axi_raddr == ADDR_AFU_SCRATCHPAD)
	  axi_rdata <= afu_scratchpad;


	// Histograms read:
	if ((axi_raddr >= ADDR_AFU_HISTO0_BASE) && (axi_raddr < ADDR_AFU_HISTO1_BASE))
	  // Reading pci2sbu_packets_size histogram
	  axi_rdata <= hist_pci2sbu_packet_dout;

	if ((axi_raddr >= ADDR_AFU_HISTO1_BASE) && (axi_raddr < ADDR_AFU_HISTO2_BASE))
	  // Reading pci2sbu_packets_size histogram
	  axi_rdata <= hist_pci2sbu_eompacket_dout;

	if ((axi_raddr >= ADDR_AFU_HISTO2_BASE) && (axi_raddr < ADDR_AFU_HISTO3_BASE))
	  // Reading pci2sbu_packets_size histogram
	  axi_rdata <= hist_pci2sbu_message_dout;

	if ((axi_raddr >= ADDR_AFU_HISTO3_BASE) && (axi_raddr < ADDR_AFU_HISTO4_BASE))
	  // Reading pci2sbu_packets_size histogram
	  axi_rdata <= hist_sbu2pci_response_dout;

	// PCI sample buffers read:
	if ((axi_raddr >= ADDR_PCI2SBU_SAMPLE_BASE) && (axi_raddr < ADDR_PCI2SBU_SAMPLE_END))
	  axi_rdata <= pci2sbu_sample_rdata;
	if ((axi_raddr >= ADDR_SBU2PCI_SAMPLE_BASE) && (axi_raddr < ADDR_SBU2PCI_SAMPLE_END))
	  axi_rdata <= sbu2pci_sample_rdata;
	if ((axi_raddr >= ADDR_MODULE_IN_SAMPLE_BASE) && (axi_raddr < ADDR_MODULE_IN_SAMPLE_END))
	  axi_rdata <= module_in_sample_rdata;
	if ((axi_raddr >= ADDR_INPUT_BUFFER_SAMPLE_BASE) && (axi_raddr < ADDR_INPUT_BUFFER_SAMPLE_END))
	  axi_rdata <= input_buffer_sample_rdata;

	if (axi_raddr == ADDR_TIMESTAMPL)
	  axi_rdata <= timestamp[31:0];
	if (axi_raddr == ADDR_TIMESTAMPH)
	  axi_rdata <= {16'h0000, timestamp[47:32]};
      end

    if (afu_counter8_cleared)
      afu_counter8_read <= 1'b0;
    if (afu_counter9_cleared)
      afu_counter9_read <= 1'b0;
  end // always @ (posedge clk)
  
  // axilite write fsm
  assign axilite_aw_rdy = (axi_wstate == WRIDLE);
  assign axilite_w_rdy  = (axi_wstate == WRDATA);
  assign axilite_b_resp = 2'b00;  // OKAY
  assign axilite_b_vld  = (axi_wstate == WRRESP);
  assign axi_aw_hs      = axilite_aw_vld & axilite_aw_rdy;
  assign axi_w_hs       = axilite_w_vld  & axilite_w_rdy;
  
  // wstate
  always @(posedge clk) begin
    if (reset)
      axi_wstate <= WRIDLE;
    else
      axi_wstate <= axi_wnext;
  end
  
  // wnext
  always @(*) begin
    case (axi_wstate)
      WRIDLE:
        if (axilite_aw_vld)
          axi_wnext = WRDATA;
        else
          axi_wnext = WRIDLE;
      WRDATA:
        if (axilite_w_vld)
          axi_wnext = WRRESP;
        else
          axi_wnext = WRDATA;
      WRRESP:
        if (axilite_b_rdy)
          axi_wnext = WRIDLE;
        else
          axi_wnext = WRRESP;
      default:
        axi_wnext = WRIDLE;
    endcase
  end
  
  // waddr
  always @(posedge clk) begin
    if (axi_aw_hs)
      axi_waddr <= {1'b0, axilite_aw_addr[AXILITE_AFU_ADDR_WIDTH-2 : 0]}; // address MSB is forced to 0, to enfoce a positive integer  
  end
  
  // writing to AFU ctrl registers
  always @(posedge clk) begin
    if (reset) begin
      afu_ctrl0 <= 32'h01ff00000; // Default: All zuc modules are enabled, fifx_in occupancy based arbitration, input_buffer watermark = 0
                                  //          EOM is forced (EOM still not implemented in FLD) 
                                  //          Modules-test-mode is disabled
                                  //          No AFU/Modules bypass
      afu_ctrl1 <= 32'b0;         // Default: fifox_in high watermark set to 0 (== no watermark). No headers metadata
      afu_ctrl2 <= 32'b0;         // Default: message id ordering is enabled to all channels. Sampling trigger disabled
      afu_ctrl3 <= 32'h00000001;  // Default: Backpressure counter8 & counter9 are cleared after being read.
      afu_ctrl4 <= 32'h00000000;  // Default: All histograms are disabled
      afu_ctrl5 <= 32'h00000000;  // Default: pci2sbu & sbu2pci axi4stream_data sampling is disabled
      afu_ctrl8 <= 32'h00000000;  // Default: Sampling trigger
      afu_ctrl9 <= 32'h00000000;  // Default: Sampling trigger
      afu_reset <= 1'b0;
      afu_reset_count <= 8'h00;
      afu_ctrl0_wr <= 1'b0;
      afu_ctrl1_wr <= 1'b0;
      afu_ctrl2_wr <= 1'b0;
      afu_ctrl3_wr <= 1'b0;
      afu_ctrl4_wr <= 1'b0;
      afu_ctrl5_wr <= 1'b0;
      afu_scratchpad <= 32'hdeadf00d;
      pci_sample_reset <= 1'b0;
      pci_sample_reset_count <= 8'h00;
    end
    else begin
      if (axi_w_hs && axi_waddr == ADDR_AFU_CTRL0)
	begin
	  afu_ctrl0[31:0] <= axilite_w_data[31:0];
	  afu_ctrl0_wr <= 1'b1; // indication that afu_ctrl0 been written. Asserted to 1 clock !!
	  if (axilite_w_data[31])
	    begin
	      afu_reset <= 1'b1;
	      afu_reset_count <= AFU_SOFT_RESET_WIDTH;
	    end
	end
      else
	  afu_ctrl0_wr <= 1'b0;

      if (axi_w_hs && axi_waddr == ADDR_AFU_CTRL1)
	begin
	  afu_ctrl1[31:0] <= axilite_w_data[31:0];
	  afu_ctrl1_wr <= 1'b1; // indication to zuc_modules that fifox_in watermark has been written. Asserted to 1 clock !!
	end
      else
	  afu_ctrl1_wr <= 1'b0;
	
      if (axi_w_hs && axi_waddr == ADDR_AFU_CTRL2)
	begin
	  afu_ctrl2[31:0] <= axilite_w_data[31:0];
	  afu_ctrl2_wr <= 1'b1; // indication that message ordering mask has been written. Asserted to 1 clock !!
	end
      else
	afu_ctrl2_wr <= 1'b0;
      
      if (axi_w_hs && axi_waddr == ADDR_AFU_CTRL3)
	begin
	  afu_ctrl3[31:0] <= axilite_w_data[31:0];
	  afu_ctrl3_wr <= 1'b1;
	end
      else
	afu_ctrl3_wr <= 1'b0;
      
      if (axi_w_hs && axi_waddr == ADDR_AFU_CTRL4)
	begin
	  afu_ctrl4[31:0] <= axilite_w_data[31:0];
	  afu_ctrl4_wr <= 1'b1; // indication that histo operation has been written. Asserted to 1 clock !!
	  if (axilite_w_data[16])
	    begin
	      pci_sample_reset <= 1'b1;
	      pci_sample_reset_count <= PCI_SAMPLE_SOFT_RESET_WIDTH;
	    end
	end
      else
	afu_ctrl4_wr <= 1'b0;

      if (axi_w_hs && axi_waddr == ADDR_AFU_CTRL5)
	begin
	  afu_ctrl5[31:0] <= axilite_w_data[31:0];
	  afu_ctrl5_wr <= 1'b1; // indication that pci sampling operation has been written. Asserted to 1 clock !!
	end
      else
	afu_ctrl5_wr <= 1'b0;
      
      if (axi_w_hs && axi_waddr == ADDR_AFU_CTRL8)
	begin
	  afu_ctrl8[31:0] <= axilite_w_data[31:0];
	end
      
      if (axi_w_hs && axi_waddr == ADDR_AFU_CTRL9)
	begin
	  afu_ctrl9[31:0] <= axilite_w_data[31:0];
	end
      
      if (axi_w_hs && axi_waddr == ADDR_AFU_SCRATCHPAD)
	afu_scratchpad[31:0] <= axilite_w_data[31:0];

      // zuc_afu reset:
      if (afu_reset)
	begin
	  if (afu_reset_count > 0)
	    // afu_reset is asserted to AFU_SOFT_RESET_WIDTH zuc_clocks
	    afu_reset_count <= afu_reset_count - 8'h01;
	  else
	    afu_reset <= 1'b0;
	end

      // pci_sample reset:
      if (pci_sample_reset)
	begin
	  if (pci_sample_reset_count > 0)
	    // pci_sample_reset is asserted to PCI_SAMPLE_SOFT_RESET_WIDTH zuc_clocks, 
	    // to accomodate for the synchronizers between the AFU FLD domains
	    pci_sample_reset_count <= pci_sample_reset_count - 8'h01;
	  else
	    pci_sample_reset <= 1'b0;
	end
    end
  end

  
  // Modules fifo_in watermark
  wire [4:0]     module_fifo_in_watermark[NUM_MODULES-1:0];
  wire 		 module_fifo_in_watermark_met[NUM_MODULES-1:0];

  // fifo_in watermark is active only in a round_robin fifo_in arbitration mode (afu_ctrl0[17:16] == 2'b11) 
  // non-zero watermark while in other fifo_in load_based arbitration mode, actually disrupts the arbitration scheme. 
  assign   module_fifo_in_watermark[0] = (afu_ctrl0[17:16] == 2'b11) ? {afu_ctrl1_wr, afu_ctrl1[3:0]} : 4'h0; 
  assign   module_fifo_in_watermark[1] = (afu_ctrl0[17:16] == 2'b11) ? {afu_ctrl1_wr, afu_ctrl1[7:4]} : 4'h0;
  assign   module_fifo_in_watermark[2] = (afu_ctrl0[17:16] == 2'b11) ? {afu_ctrl1_wr, afu_ctrl1[11:8]} : 4'h0;
  assign   module_fifo_in_watermark[3] = (afu_ctrl0[17:16] == 2'b11) ? {afu_ctrl1_wr, afu_ctrl1[15:12]} : 4'h0;
  assign   module_fifo_in_watermark[4] = (afu_ctrl0[17:16] == 2'b11) ? {afu_ctrl1_wr, afu_ctrl1[19:16]} : 4'h0;
  assign   module_fifo_in_watermark[5] = (afu_ctrl0[17:16] == 2'b11) ? {afu_ctrl1_wr, afu_ctrl1[23:20]} : 4'h0;
  assign   module_fifo_in_watermark[6] = (afu_ctrl0[17:16] == 2'b11) ? {afu_ctrl1_wr, afu_ctrl1[27:24]} : 4'h0;
  assign   module_fifo_in_watermark[7] = (afu_ctrl0[17:16] == 2'b11) ? {afu_ctrl1_wr, afu_ctrl1[31:28]} : 4'h0;

  wire   module_in_test_mode;
  assign module_in_test_mode = afu_ctrl0[29];


//===================================================================================================================================
// zuc AFU
//===================================================================================================================================
//
// AFU Input buffer: Message buffering scheme:
// Input buffer is physically split to 16 queues, with dedicated chidx_head/chidx_tail pointers (wrapped around the queue size)
// After last input message in channel x is complete (EOM has been observed), ... 
//    chidx_head points to beginning of the oldest received message in channel ID x
//    chidx_tail points to next free line to be written with next incoming message
//    chidx_message_size specifies the total number of bytes in latter received message, which is then stored the the message header
//
// A message buffer begins with one header 512b line, followed by the rest of the message data
//    Once a message input is complete (EOM arrived), a 512b header is prepended to the message data, 
//    (written to the beginning of current message buffer) including message info: USER, Channel ID, Message size, EOM Indicatoin, etc
//
// The Message Buffering Scheme state machine also implements the interaction with pci2sbu input port.
//    Input_buffer space availability per chidx is calculated per channel:
//       chidx_buffer_full = chidx_tail - chidx_head
// upon arrival of message data line from pci2sbu:
// 1. If (pci2sbu_axi4stream_vld & chidx_eom) // start_of_new_message
//       chidx_eom = '0;
//       Sample relevant TUSER info at first message line
//          {chidx, chidx_user} = pci2sbu_axi4stream_tuser...  
//       First message line in input_buffer is cleared, to avoid false header indication
//       This line will be later updated with correct header, once the whole message has been received (step #7 below)
//       For this purpose, a copy of chidx_tail (which currently points to the message start) is saved
//          chidx_message_start = chidx_tail
//          input_buffer(chidx_tail++) <- 0  
//          chidx_message_size = 0;
//    endif
// 2. input_buffer(chidx_tail++) <- pci2sbu_axi4stream_tdata[masked by tkeep])
// 4. Update chidx_message_size (masked by tkeep)
// 5. assign chidx_header = chidx, chidx_message_size, chidx_user // continuously update chidx_header line
// 6. Repeat 1..5 until EOM  
//
// Upon arrival of EOM (line containing EOM already stored at step 2 above):
// 7. Mark end_of_message
//    chidx_eom = '1;
//    Store the message header to first line in latter stored message:
//    Implementation note: This technique may impose a critical path of read after write.
//        Pay attention to force at least one clock delay for read_after_write operation
//    input_buffer(chidx_message_start) <- chidx_header
// 8. chidx_in_message_count++;  // Holds number of complete messages in chidx input buffer. Used in Message Read Scheme. See below
// 9. Repeat from 1 // wait for next line from pci2sbu

  // AFU status:
  wire 	 [31:0] afu_status;
  wire 	 [15:0] chid_in_buffers_not_empty;
  
  assign chid_in_buffers_not_empty = {chid_in_buffer_not_empty[15],chid_in_buffer_not_empty[14],chid_in_buffer_not_empty[13],chid_in_buffer_not_empty[12],
				  chid_in_buffer_not_empty[11],chid_in_buffer_not_empty[10], chid_in_buffer_not_empty[9], chid_in_buffer_not_empty[8],
				  chid_in_buffer_not_empty[7], chid_in_buffer_not_empty[6], chid_in_buffer_not_empty[5], chid_in_buffer_not_empty[4],
				  chid_in_buffer_not_empty[3], chid_in_buffer_not_empty[2], chid_in_buffer_not_empty[1], chid_in_buffer_not_empty[0]};
  
  assign afu_status[23:20] =  current_in_chid;
  assign afu_status[19] = trigger_is_met;
  assign afu_status[18:16] = {packet_in_nstate != 3'h0, message_out_nstate != 4'h0, sbu2pci_out_nstate != 4'h0};
  assign afu_status[15:8] = {zuc_out_stats[7][3:0] != 4'h0, zuc_out_stats[6][3:0] != 4'h0, zuc_out_stats[5][3:0] != 4'h0, zuc_out_stats[4][3:0] != 4'h0,
                             zuc_out_stats[3][3:0] != 4'h0, zuc_out_stats[2][3:0] != 4'h0, zuc_out_stats[1][3:0] != 4'h0, zuc_out_stats[0][3:0] != 4'h0};
  assign afu_status[5] =  current_in_buffer_full;
  assign afu_status[4] = (chid_in_buffers_not_empty == 16'h0000) ? 1'b0 : 1'b1;
  assign afu_status[3] = (messages_validD == 16'h0000) ? 1'b0 : 1'b1;
  assign afu_status[2] = (fifo3_out_message_count == 8'h000 && fifo2_out_message_count == 8'h000 &&
			  fifo1_out_message_count == 8'h000 && fifo0_out_message_count == 8'h000 &&
			  fifo7_out_message_count == 8'h000 && fifo6_out_message_count == 8'h000 &&
			  fifo5_out_message_count == 8'h000 && fifo4_out_message_count == 8'h000) ? 1'b0 : 1'b1;
  assign afu_status[1] = (fifo_out_message_valid_regD == 8'h00) ? 1'b0 : 1'b1;
  assign afu_status[0] = (afu_status[18:8] == 11'h000 && afu_status[4:1] == 4'h00) ? 1'b0 : 1'b1;

// zuc_afu status & statistis registers
  always @(posedge clk) begin
    if (reset || afu_reset)
      begin
	afu_counter0 <= 32'h00000000;
	afu_counter1 <= 32'h00000000;
	afu_counter2 <= 32'h00000000;
	afu_counter3 <= 32'h00000000;
	afu_counter4 <= 32'h00000000;
	afu_counter5 <= 32'h00000000;
	afu_counter6 <= 32'h00000000;
	afu_counter7 <= 32'h00000000;
	afu_counter8 <= 33'h000000000;
	afu_counter9 <= 33'h000000000;
	afu_counter8_cleared <= 1'b0;
	afu_counter9_cleared <= 1'b0;
	timestamp <= 48'h00000000000;
      end
    else
      begin
	// Free running counter, used to timestamp afu samples.
	// Count is started immediately after reset (either hard or soft reset).
	// Count is wrapped around 2^48
	// Max time duration (@ 125 Mhz zuc clock): 2^48 / 125 * 10^6 = 2252800 sec = 625 hours 
	timestamp <= timestamp + 1'b1;

	// counter0
	// [31:16]  - per channel, data_flits count > 0, in input buffer. chidx at bit [x]
	// [15:0]   - per channel, message count > 0, in input buffer. chidx at bit [x]
	afu_counter0 <= {chid_in_buffers_not_empty, messages_validD};

	// counter1: AFU status
	// [31:24]   Reserved
	// [23:20]   Currently received channel ID
	//    [19]   Reserved
	// [18:16]   Either of {packet_in_nstate, message_out_nstate, sbu2pci_out_nstate} SMs is busy
	//  [15:8]   Either of zuc_modules SMs is busy
	//   [7:6]   Reserved
	//     [5]   Input buffer of currently received chid is full
	//     [4]   There are data flits in input buffer, in either of the channels
	//     [3]   There are pending message requests in input buffer, in either of the channels
	//     [2]   Pending responses count in fifox_out is not zero
	//     [1]   There are Pending responses in fifox_out
	//     [0]   AFU is busy
	afu_counter1 <= {8'h00, afu_status[23:20], afu_status[19:8], 2'b00, afu_status[5:0]};

	// counter2
	// [31:16] - reserved
	// [15:8]  - fifox_in has sufficient free space, and fifox with the maximum free space is selected at bit [x]
	// [7:0]   - fifox_out has at least one valid message, fifox at bit [x]
	afu_counter2 <= {16'h0000, fifo_in_free_regD, fifo_out_message_valid_regD};

	// counter3
	// [31:24] - fifo3_out message count
	// [23:16] - fifo2_out message count
	// [15:8]  - fifo1_out message count
	// [7:0]   - fifo0_out message count
	afu_counter3 <= {fifo3_out_message_count[7:0], fifo2_out_message_count[7:0], fifo1_out_message_count[7:0], fifo0_out_message_count[7:0]};

	// counter4
	// [31:24] - fifo7_out message count
	// [23:16] - fifo6_out message count
	// [15:8]  - fifo5_out message count
	// [7:0]   - fifo4_out message count
	afu_counter4 <= {fifo7_out_message_count[7:0], fifo6_out_message_count[7:0], fifo5_out_message_count[7:0], fifo4_out_message_count[7:0]};

	// counter6 - afu state machines
	// [31:16]  - Reserved
	// [15:2]   - Reserved
	// [11:8]   - zuc_modules fifox_out to sbu2pci SM
	// [7:4]    - input_buffer to zuc_modules fifox_in SM
	// [3:0]    - pci2sbu to input_buffer SM
	afu_counter6 <= {20'h00000, sbu2pci_out_nstate, message_out_nstate, 1'b0, packet_in_nstate};

	// counter7 - zuc modules state machines
	// [31:28]  - zuc module7 SM
	// [27:24]  - zuc module6 SM
	// [23:20]  - zuc module5 SM
	// [19:16]  - zuc module4 SM
	// [15:12]  - zuc module3 SM
	// [11:8]   - zuc module2 SM
	// [7:4]    - zuc module1 SM
	// [3:0]    - zuc module0 SM
	afu_counter7 <= {zuc_out_stats[7][3:0], zuc_out_stats[6][3:0], zuc_out_stats[5][3:0], zuc_out_stats[4][3:0],
			 zuc_out_stats[3][3:0], zuc_out_stats[2][3:0], zuc_out_stats[1][3:0], zuc_out_stats[0][3:0]};

	// counter8 - pci2sbu pushback_by_afu zuc_clk ticks
	// [31:0]   - pci2sbu pushback ticks, saturated at max unsigned 32bit value 
	//          - The counter is cleared at reset or after being read to axi4lite
	if (afu_counter8_read) 
	  // The counter is cleared at reset or upon being read to axi4lite
	  begin
	    afu_counter8 <= 33'b0;
	    afu_counter8_cleared <= 1'b1;
	  end
	else if (pci2sbu_axi4stream_vld && ~pci2sbu_axi4stream_rdy)
	  // pci2sbu is pushed back by afu, and not being read to axi4lite
	  begin
	    if (afu_counter8 < 33'h0ffffffff)
	      // Count is saturated at max unsigned 32bit value.
	      begin
		afu_counter8 <= afu_counter8 + 1;
		afu_counter8_cleared <= 1'b0;
	      end
	  end

	// counter9 - sbu2pci pushback_by_pci zuc_clk ticks
	// [31:0]   - sbu2pci pushback ticks, saturated at max unsigned 32bit value 
	//          - The counter is cleared at reset or after being read to axi4lite
	if (afu_counter9_read) 
	  // The counter is cleared at reset or upon being read to axi4lite
	  begin
	    afu_counter9 <= 33'b0;
	    afu_counter9_cleared <= 1'b1;
	  end
	else if (sbu2pci_axi4stream_vld && ~sbu2pci_axi4stream_rdy)
	  // sbu2pci is pushed back by pci, and not being read to axi4lite
	  begin
	    if (afu_counter9 < 33'h0ffffffff)
	      // Count is saturated at max unsigned 32bit value.
	      begin
		afu_counter9 <= afu_counter9 + 1;
		afu_counter9_cleared <= 1'b0;
	      end
	  end
      end
  end
    
  reg         pci2sbu_ready;
  reg 	      sbu2pci_valid;
  
  reg 	      current_in_eom;
  reg 	      current_in_pkt_type;
  reg [12:0]  current_in_headD;
  reg [12:0]  current_in_head;
  
  reg 	      current_in_somD;
  reg 	      current_in_som;
  reg 	      chid0_in_som;
  reg 	      chid1_in_som;
  reg 	      chid2_in_som;
  reg 	      chid3_in_som;
  reg 	      chid4_in_som;
  reg 	      chid5_in_som;
  reg 	      chid6_in_som;
  reg 	      chid7_in_som;
  reg 	      chid8_in_som;
  reg 	      chid9_in_som;
  reg 	      chid10_in_som;
  reg 	      chid11_in_som;
  reg 	      chid12_in_som;
  reg 	      chid13_in_som;
  reg 	      chid14_in_som;
  reg 	      chid15_in_som;

  reg 	      current_out_eom;
  reg 	      current_out_som;
  reg 	      chid0_out_som;
  reg 	      chid1_out_som;
  reg 	      chid2_out_som;
  reg 	      chid3_out_som;
  reg 	      chid4_out_som;
  reg 	      chid5_out_som;
  reg 	      chid6_out_som;
  reg 	      chid7_out_som;
  reg 	      chid8_out_som;
  reg 	      chid9_out_som;
  reg 	      chid10_out_som;
  reg 	      chid11_out_som;
  reg 	      chid12_out_som;
  reg 	      chid13_out_som;
  reg 	      chid14_out_som;
  reg 	      chid15_out_som;

  reg [12:0]  current_in_tailD;
  reg [12:0]  current_in_tail;
  reg 	      current_in_tail_incremented;
  reg [12:0]  chid0_in_tail;
  reg [12:0]  chid1_in_tail;
  reg [12:0]  chid2_in_tail;
  reg [12:0]  chid3_in_tail;
  reg [12:0]  chid4_in_tail;
  reg [12:0]  chid5_in_tail;
  reg [12:0]  chid6_in_tail;
  reg [12:0]  chid7_in_tail;
  reg [12:0]  chid8_in_tail;
  reg [12:0]  chid9_in_tail;
  reg [12:0]  chid10_in_tail;
  reg [12:0]  chid11_in_tail;
  reg [12:0]  chid12_in_tail;
  reg [12:0]  chid13_in_tail;
  reg [12:0]  chid14_in_tail;
  reg [12:0]  chid15_in_tail;
  
  reg [12:0]  current_out_headD;
  reg [12:0]  current_out_head;
  reg 	      current_out_head_incremented;
  reg [12:0]  chid0_out_head;
  reg [12:0]  chid1_out_head;
  reg [12:0]  chid2_out_head;
  reg [12:0]  chid3_out_head;
  reg [12:0]  chid4_out_head;
  reg [12:0]  chid5_out_head;
  reg [12:0]  chid6_out_head;
  reg [12:0]  chid7_out_head;
  reg [12:0]  chid8_out_head;
  reg [12:0]  chid9_out_head;
  reg [12:0]  chid10_out_head;
  reg [12:0]  chid11_out_head;
  reg [12:0]  chid12_out_head;
  reg [12:0]  chid13_out_head;
  reg [12:0]  chid14_out_head;
  reg [12:0]  chid15_out_head;


  reg [11:0]   current_in_message_idD;
  reg [11:0]   current_in_message_id;
  reg [11:0]   chid0_in_message_id;
  reg [11:0]   chid1_in_message_id;
  reg [11:0]   chid2_in_message_id;
  reg [11:0]   chid3_in_message_id;
  reg [11:0]   chid4_in_message_id;
  reg [11:0]   chid5_in_message_id;
  reg [11:0]   chid6_in_message_id;
  reg [11:0]   chid7_in_message_id;
  reg [11:0]   chid8_in_message_id;
  reg [11:0]   chid9_in_message_id;
  reg [11:0]   chid10_in_message_id;
  reg [11:0]   chid11_in_message_id;
  reg [11:0]   chid12_in_message_id;
  reg [11:0]   chid13_in_message_id;
  reg [11:0]   chid14_in_message_id;
  reg [11:0]   chid15_in_message_id;

  reg [9:0]   chid_in_message_count[NUM_CHANNELS-1:0];

  reg [31:0]   total_chid0_in_message_count;
  reg [31:0]   total_chid1_in_message_count;
  reg [31:0]   total_chid2_in_message_count;
  reg [31:0]   total_chid3_in_message_count;
  reg [31:0]   total_chid4_in_message_count;
  reg [31:0]   total_chid5_in_message_count;
  reg [31:0]   total_chid6_in_message_count;
  reg [31:0]   total_chid7_in_message_count;
  reg [31:0]   total_chid8_in_message_count;
  reg [31:0]   total_chid9_in_message_count;
  reg [31:0]   total_chid10_in_message_count;
  reg [31:0]   total_chid11_in_message_count;
  reg [31:0]   total_chid12_in_message_count;
  reg [31:0]   total_chid13_in_message_count;
  reg [31:0]   total_chid14_in_message_count;
  reg [31:0]   total_chid15_in_message_count;
  reg [63:0]   total_in_message_count;

  reg [9:0]   current_in_message_linesD; // Number of received pci2sbu_tdata lines. Max value: 9KB/mesage ==> ('d144 == 'h90) x 512b lines
  reg [9:0]   current_in_message_lines;
  reg [9:0]   chid0_in_message_lines;
  reg [9:0]   chid1_in_message_lines;
  reg [9:0]   chid2_in_message_lines;
  reg [9:0]   chid3_in_message_lines;
  reg [9:0]   chid4_in_message_lines;
  reg [9:0]   chid5_in_message_lines;
  reg [9:0]   chid6_in_message_lines;
  reg [9:0]   chid7_in_message_lines;
  reg [9:0]   chid8_in_message_lines;
  reg [9:0]   chid9_in_message_lines;
  reg [9:0]   chid10_in_message_lines;
  reg [9:0]   chid11_in_message_lines;
  reg [9:0]   chid12_in_message_lines;
  reg [9:0]   chid13_in_message_lines;
  reg [9:0]   chid14_in_message_lines;
  reg [9:0]   chid15_in_message_lines;

  reg [12:0]   current_in_message_startD; // start address of currently received  message in input buffer
  reg [12:0]   current_in_message_start;
  reg [12:0]   chid0_in_message_start;
  reg [12:0]   chid1_in_message_start;
  reg [12:0]   chid2_in_message_start;
  reg [12:0]   chid3_in_message_start;
  reg [12:0]   chid4_in_message_start;
  reg [12:0]   chid5_in_message_start;
  reg [12:0]   chid6_in_message_start;
  reg [12:0]   chid7_in_message_start;
  reg [12:0]   chid8_in_message_start;
  reg [12:0]   chid9_in_message_start;
  reg [12:0]   chid10_in_message_start;
  reg [12:0]   chid11_in_message_start;
  reg [12:0]   chid12_in_message_start;
  reg [12:0]   chid13_in_message_start;
  reg [12:0]   chid14_in_message_start;
  reg [12:0]   chid15_in_message_start;

  reg [15:0]   current_in_message_sizeD; // Message size, as indicated in message_header[495:480]
  reg [15:0]   current_in_message_size;
  reg [15:0]   chid0_in_message_size;
  reg [15:0]   chid1_in_message_size;
  reg [15:0]   chid2_in_message_size;
  reg [15:0]   chid3_in_message_size;
  reg [15:0]   chid4_in_message_size;
  reg [15:0]   chid5_in_message_size;
  reg [15:0]   chid6_in_message_size;
  reg [15:0]   chid7_in_message_size;
  reg [15:0]   chid8_in_message_size;
  reg [15:0]   chid9_in_message_size;
  reg [15:0]   chid10_in_message_size;
  reg [15:0]   chid11_in_message_size;
  reg [15:0]   chid12_in_message_size;
  reg [15:0]   chid13_in_message_size;
  reg [15:0]   chid14_in_message_size;
  reg [15:0]   chid15_in_message_size;

  reg [10:0]   current_in_buffer_data_countD;
  reg [10:0]   chid_in_buffer_data_count[NUM_CHANNELS-1:0];
  reg 	       chid_in_buffer_not_empty[NUM_CHANNELS-1:0];

  reg [7:0]   current_in_opcode; // Message opcode
  reg [7:0]   current_in_opcodeD; // Message opcode
  reg [7:0]   chid0_in_opcode;
  reg [7:0]   chid1_in_opcode;
  reg [7:0]   chid2_in_opcode;
  reg [7:0]   chid3_in_opcode;
  reg [7:0]   chid4_in_opcode;
  reg [7:0]   chid5_in_opcode;
  reg [7:0]   chid6_in_opcode;
  reg [7:0]   chid7_in_opcode;
  reg [7:0]   chid8_in_opcode;
  reg [7:0]   chid9_in_opcode;
  reg [7:0]   chid10_in_opcode;
  reg [7:0]   chid11_in_opcode;
  reg [7:0]   chid12_in_opcode;
  reg [7:0]   chid13_in_opcode;
  reg [7:0]   chid14_in_opcode;
  reg [7:0]   chid15_in_opcode;
  
  reg [15:0]   input_buffer_watermark_met; // per channel indication: (input_buffer_watermark_met[x]==1) ==> watermark has been met for chidx
  reg [9:0]    input_buffer_watermark;
  reg [12:0]   current_in_message_status_update;
  reg [12:0]   current_in_message_status_adrs;
  reg [7:0]    current_in_message_status; // Incoming message status
  reg [7:0]    current_fifo_in_message_cmd;
  reg 	       current_fifo_in_message_ok;
  reg 	       current_fifo_in_message_type;
  reg 	       current_fifo_in_header;
  reg 	       current_fifo_in_eth_header;
  
  reg [2:0]    current_fifo_in_id;
  wire 	       current_in_zuccmd;
  wire 	       current_in_illegal_cmd;
  reg 	       current_in_message_ok;
  reg 	       current_in_mask_message_id;
  reg [3:0]    current_in_context;
  reg [3:0]    current_in_chid;
  reg [3:0]    current_out_chid;
  reg [4:0]    current_out_chid_delta;
  reg [3:0]    current_out_context;
  reg 	       update_channel_in_regs;
  reg 	       update_channel_out_regs;
  reg 	       update_fifo_in_regs;
  
  reg [3:0]    message_out_nstate;
  reg 	       input_buffer_rden;
  wire 	       current_fifo_in_message_eom;
  reg [47:0]   current_fifo_in_message_metadata;
  reg [15:0]   current_fifo_in_message_size;
  reg [15:0]   current_fifo_in_message_words;
  reg [10:0]   current_fifo_in_message_lines;
  reg [7:0]    current_fifo_in_message_status;
  wire	       fifo_in_ready[NUM_MODULES-1:0];
  reg	       module_in_valid;
  wire	       fifo_out_valid[NUM_MODULES-1:0];
  reg 	       message_afubypass_pending;
  reg 	       message_data_valid;
  reg 	       message_afubypass_valid;
  
  reg 	       fifo_in_readyD;
  reg 	       fifo_in_readyQ;
  reg 	       input_buffer_write;
  reg 	       input_buffer_meta_write;
  reg 	       input_buffer_wren;
  reg 	       write_eth_header;
  reg 	       packet_in_progress;
  reg [2:0]    packet_in_nstate;
  reg [335:0]  current_in_eth_header; // Holding the relevant part in message header, for both RDMA RC and Ethernet headers
  
  wire 	       message_out_validD;
  wire [15:0]  messages_validD;
  wire [31:0]  messages_valid_doubleregD;
  reg 	       fifo_in_full[NUM_MODULES-1:0];
  wire 	       fifo_in_free_regD0;
  wire 	       fifo_in_free_regD1;
  wire 	       fifo_in_free_regD2;
  wire 	       fifo_in_free_regD3;
  wire 	       fifo_in_free_regD4;
  wire 	       fifo_in_free_regD5;
  wire 	       fifo_in_free_regD6;
  wire 	       fifo_in_free_regD7;
  wire [7:0]   fifo_in_free_regD;
  wire [15:0]   fifo_in_free_doubleregD;
  reg [3:0]    fifo_in_id_delta;
  wire 	       zuc_module0_enable;
  wire 	       zuc_module1_enable;
  wire 	       zuc_module2_enable;
  wire 	       zuc_module3_enable;
  wire 	       zuc_module4_enable;
  wire 	       zuc_module5_enable;
  wire 	       zuc_module6_enable;
  wire 	       zuc_module7_enable;
  
  wire [515:0] module_in_data;
  
  wire [5:0]   next_out_chid;
  wire [15:0]  fifo7_in_free_count;
  wire [15:0]  fifo6_in_free_count;
  wire [15:0]  fifo5_in_free_count;
  wire [15:0]  fifo4_in_free_count;
  wire [15:0]  fifo3_in_free_count;
  wire [15:0]  fifo2_in_free_count;
  wire [15:0]  fifo1_in_free_count;
  wire [15:0]  fifo0_in_free_count;
  wire [3:0]   next_fifo_in_id;
  
  // ???? TBD: Check possible optimization of this logic, assuming message_data is always DW aligned 
  wire [63:0]  current_out_keep;
  wire [515:0] message_afubypass_data;
  reg [515:0]  fifo_out_dataD;
  reg 	       fifo_out_lastD;
  wire 	       fifo_out_last[NUM_MODULES-1:0];
  reg 	       fifo_out_userD;
  wire 	       fifo_out_user[NUM_MODULES-1:0];
  reg [7:0]    fifo_out_statusD;
  wire [11:0]  fifo0_out_message_id;
  wire [11:0]  fifo1_out_message_id;
  wire [11:0]  fifo2_out_message_id;
  wire [11:0]  fifo3_out_message_id;
  wire [11:0]  fifo4_out_message_id;
  wire [11:0]  fifo5_out_message_id;
  wire [11:0]  fifo6_out_message_id;
  wire [11:0]  fifo7_out_message_id;
  wire [3:0]  fifo0_out_chid;
  wire [3:0]  fifo1_out_chid;
  wire [3:0]  fifo2_out_chid;
  wire [3:0]  fifo3_out_chid;
  wire [3:0]  fifo4_out_chid;
  wire [3:0]  fifo5_out_chid;
  wire [3:0]  fifo6_out_chid;
  wire [3:0]  fifo7_out_chid;
  wire [11:0]  fifo0_out_expected_message_id;
  wire [11:0]  fifo1_out_expected_message_id;
  wire [11:0]  fifo2_out_expected_message_id;
  wire [11:0]  fifo3_out_expected_message_id;
  wire [11:0]  fifo4_out_expected_message_id;
  wire [11:0]  fifo5_out_expected_message_id;
  wire [11:0]  fifo6_out_expected_message_id;
  wire [11:0]  fifo7_out_expected_message_id;
  wire [7:0]   fifo_out_message_valid_regD;
  wire [15:0]  fifo_out_message_valid_doubleregD;
  reg [3:0]    current_fifo_out_id;
  reg [3:0]    fifo_out_id_delta;
  wire [3:0]   next_fifo_out_id;
  reg [11:0]   current_fifo_out_message_id;
  reg [15:0]   current_fifo_out_message_size;
  reg [15:0]   ip_header_length;
  reg [15:0]   udp_header_length;
  reg 	       sbu2pci_afubypass_inprogress;
  reg [3:0]    sbu2pci_out_nstate;
  reg	       module_out_ready;
  reg	       module_out_status_ready;
  wire 	       fifo_out_status_valid[NUM_MODULES-1:0];
  
  reg 	       update_fifo_out_regs;
  reg [3:0]    current_fifo_out_chid;
  reg [3:0]    current_fifo_out_status;
  
  reg [15:0]   fifo0_in_total_load;  // Total load held in fifox_in.
                                     // Equivalent to total clocks, it takes the zucx_module to handle the whole fifox_in content
                                     // Max fifox_in load is when it holds maximum number of shortest messages:
                                     // Max messages in fifox_in  = input_buffer_size / shortest message size = 512/4 = 128 messages
                                     // Max load: max_messages x message latency: 128 * 62 clocks = 'd7936 = 'h1f00
                                     //
                                     // fifox_in_total_load update scheme: 
                                     // Upon adding a new message to fifox_in, it is incremented with the message_size/4 + message_overhead (48 clocks)  
                                     // Once the message zuc init ended, the message overhead (48) is deducted from *total_load
                                     // Once the message flit is done, the flit length (between 1 and 16) is deducted from *total_load
  reg [15:0]    fifo1_in_total_load;
  reg [15:0]    fifo2_in_total_load;
  reg [15:0]    fifo3_in_total_load;
  reg [15:0]    fifo4_in_total_load;
  reg [15:0]    fifo5_in_total_load;
  reg [15:0]    fifo6_in_total_load;
  reg [15:0]    fifo7_in_total_load;
  reg [8:0]    fifo0_in_message_count;
  reg [8:0]    fifo1_in_message_count;
  reg [8:0]    fifo2_in_message_count;
  reg [8:0]    fifo3_in_message_count;
  reg [8:0]    fifo4_in_message_count;
  reg [8:0]    fifo5_in_message_count;
  reg [8:0]    fifo6_in_message_count;
  reg [8:0]    fifo7_in_message_count;
  reg [8:0]    fifo0_out_message_count;
  reg [8:0]    fifo1_out_message_count;
  reg [8:0]    fifo2_out_message_count;
  reg [8:0]    fifo3_out_message_count;
  reg [8:0]    fifo4_out_message_count;
  reg [8:0]    fifo5_out_message_count;
  reg [8:0]    fifo6_out_message_count;
  reg [8:0]    fifo7_out_message_count;
  reg [15:0]   chid0_last_message_id;
  reg [15:0]   chid1_last_message_id;
  reg [15:0]   chid2_last_message_id;
  reg [15:0]   chid3_last_message_id;
  reg [15:0]   chid4_last_message_id;
  reg [15:0]   chid5_last_message_id;
  reg [15:0]   chid6_last_message_id;
  reg [15:0]   chid7_last_message_id;
  reg [15:0]   chid8_last_message_id;
  reg [15:0]   chid9_last_message_id;
  reg [15:0]   chid10_last_message_id;
  reg [15:0]   chid11_last_message_id;
  reg [15:0]   chid12_last_message_id;
  reg [15:0]   chid13_last_message_id;
  reg [15:0]   chid14_last_message_id;
  reg [15:0]   chid15_last_message_id;
  
  reg [15:0]   fifo0_out_last_message_id;
  reg [15:0]   fifo1_out_last_message_id;
  reg [15:0]   fifo2_out_last_message_id;
  reg [15:0]   fifo3_out_last_message_id;
  reg [15:0]   fifo4_out_last_message_id;
  reg [15:0]   fifo5_out_last_message_id;
  reg [15:0]   fifo6_out_last_message_id;
  reg [15:0]   fifo7_out_last_message_id;

  reg [31:0]   total_fifo0_out_message_count;
  reg [31:0]   total_fifo1_out_message_count;
  reg [31:0]   total_fifo2_out_message_count;
  reg [31:0]   total_fifo3_out_message_count;
  reg [31:0]   total_fifo4_out_message_count;
  reg [31:0]   total_fifo5_out_message_count;
  reg [31:0]   total_fifo6_out_message_count;
  reg [31:0]   total_fifo7_out_message_count;
  reg [35:0]   total_zuc_out_message_count;
  reg [35:0]   total_sbu2pci_out_message_count;
  reg [35:0]   total_afubypass_message_count;

  wire [12:0]  input_buffer_wadrs;
  wire [12:0]  input_buffer_meta_wadrs;
  wire [515:0] input_buffer_wdata;
  wire [47:0]  input_buffer_meta_wdata;
  wire [12:0]  input_buffer_radrs;
  wire [515:0] input_buffer_rd;
  wire [515:0] input_buffer_rdata;
  wire [47:0]  input_buffer_meta_rdata;
  wire 	       update_zuc_module_regs[NUM_MODULES-1:0];
  wire [515:0] fifo_out_data[NUM_MODULES-1:0];
  wire [7:0]   fifo_out_status[NUM_MODULES-1:0];
  
  wire [9:0]   fifo_in_data_count[NUM_MODULES-1:0];

  wire [7:0]   zuc0_status_data;
  wire [7:0]   zuc1_status_data;
  wire [7:0]   zuc2_status_data;
  wire [7:0]   zuc3_status_data;
  wire [31:0]  zuc_out_stats[NUM_MODULES-1:0];
  wire [15:0]  zuc_progress[NUM_MODULES-1:0];
  reg [2:0]    input_buffer_read_latency;

  wire 	       current_in_buffer_full;
  wire 	       current_in_buffer_watermark_met;
  wire 	       current_out_last;
  reg [7:0]    current_response_cmd;
  reg          current_out_zuccmd;
  reg          current_fifo_out_message_type; // 0: EThernet, 1: RDMA RC
  reg [11:0]   current_response_tuser;

  

  assign pci2sbu_axi4stream_rdy = pci2sbu_ready;

// TBD: connect to afu events
  assign afu_events = 64'b0;

  assign next_out_chid = {1'b0, current_out_chid} + current_out_chid_delta;
  assign next_fifo_in_id = {1'b0, current_fifo_in_id} + fifo_in_id_delta;

  assign fifo7_in_free_count = MODULE_FIFO_IN_SIZE - {6'b0, fifo_in_data_count[7]};
  assign fifo6_in_free_count = MODULE_FIFO_IN_SIZE - {6'b0, fifo_in_data_count[6]};
  assign fifo5_in_free_count = MODULE_FIFO_IN_SIZE - {6'b0, fifo_in_data_count[5]};
  assign fifo4_in_free_count = MODULE_FIFO_IN_SIZE - {6'b0, fifo_in_data_count[4]};
  assign fifo3_in_free_count = MODULE_FIFO_IN_SIZE - {6'b0, fifo_in_data_count[3]};
  assign fifo2_in_free_count = MODULE_FIFO_IN_SIZE - {6'b0, fifo_in_data_count[2]};
  assign fifo1_in_free_count = MODULE_FIFO_IN_SIZE - {6'b0, fifo_in_data_count[1]};
  assign fifo0_in_free_count = MODULE_FIFO_IN_SIZE - {6'b0, fifo_in_data_count[0]};

  assign next_fifo_out_id = (current_fifo_out_id + fifo_out_id_delta) & 4'h7; // MOD 8 addition
  

// Input Message buffering logic:
// ==============================  
//channel_in (write) arguments selection
  always @(*) begin
    case (current_in_chid)
      0:
	begin
	  current_in_tailD = chid0_in_tail;  // write_to pointer
	  current_in_headD = chid0_out_head; // read pointer. The out_head pointer is used to calculate free space in chidx_input_buffer
              	                             // Notice that *_out_head register is updated by the message read SM 
	  current_in_somD = chid0_in_som;    // All messages in current channel buffer are complete. No partial messages
	                                     // som will be cleared once next message started to be written to buffer
	                                     // som will be set once last line of last packet has been written to buffer  
	  current_in_message_idD = chid0_in_message_id; // Locally generated message ID, to be used for messages ordering to sbu2pci
                                             // Messages IDs are sequentially incremented. wrapped around a 10 bit counter.
	                                     // A separate message ID counter per channnel
	                                     // Per channel, both enc and auth messages share the same ID counter
	  current_in_message_sizeD = chid0_in_message_size;
	  current_in_opcodeD = chid0_in_opcode;
	  current_in_message_startD = chid0_in_message_start;
	  current_in_message_linesD = chid0_in_message_lines;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[0];
	end
      1:
	begin
	  current_in_tailD = chid1_in_tail;
	  current_in_headD = chid1_out_head;
	  current_in_somD = chid1_in_som;
	  current_in_message_sizeD = chid1_in_message_size;
	  current_in_opcodeD = chid1_in_opcode;
	  current_in_message_startD = chid1_in_message_start;
	  current_in_message_linesD = chid1_in_message_lines;
	  current_in_message_idD = chid1_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[1];
	end
      
      2:
	begin
	  current_in_tailD = chid2_in_tail;
	  current_in_headD = chid2_out_head;
	  current_in_somD = chid2_in_som;
	  current_in_message_sizeD = chid2_in_message_size;
	  current_in_opcodeD = chid2_in_opcode;
	  current_in_message_startD = chid2_in_message_start;
	  current_in_message_linesD = chid2_in_message_lines;
	  current_in_message_idD = chid2_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[2];
	end
      
      3:
	begin
	  current_in_tailD = chid3_in_tail;
	  current_in_headD = chid3_out_head;
	  current_in_somD = chid3_in_som;
	  current_in_message_sizeD = chid3_in_message_size;
	  current_in_opcodeD = chid3_in_opcode;
	  current_in_message_startD = chid3_in_message_start;
	  current_in_message_linesD = chid3_in_message_lines;
	  current_in_message_idD = chid3_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[3];
	end
      
      4:
	begin
	  current_in_tailD = chid4_in_tail;
	  current_in_headD = chid4_out_head;
	  current_in_somD = chid4_in_som;
	  current_in_message_sizeD = chid4_in_message_size;
	  current_in_opcodeD = chid4_in_opcode;
	  current_in_message_startD = chid4_in_message_start;
	  current_in_message_linesD = chid4_in_message_lines;
	  current_in_message_idD = chid4_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[4];
	end
      
      5:
	begin
	  current_in_tailD = chid5_in_tail;
	  current_in_headD = chid5_out_head;
	  current_in_somD = chid5_in_som;
	  current_in_message_sizeD = chid5_in_message_size;
	  current_in_opcodeD = chid5_in_opcode;
	  current_in_message_startD = chid5_in_message_start;
	  current_in_message_linesD = chid5_in_message_lines;
	  current_in_message_idD = chid5_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[5];
	end
      
      6:
	begin
	  current_in_tailD = chid6_in_tail;
	  current_in_headD = chid6_out_head;
	  current_in_somD = chid6_in_som;
	  current_in_message_sizeD = chid6_in_message_size;
	  current_in_opcodeD = chid6_in_opcode;
	  current_in_message_startD = chid6_in_message_start;
	  current_in_message_linesD = chid6_in_message_lines;
	  current_in_message_idD = chid6_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[6];
	end
      
      7:
	begin
	  current_in_tailD = chid7_in_tail;
	  current_in_headD = chid7_out_head;
	  current_in_somD = chid7_in_som;
	  current_in_message_sizeD = chid7_in_message_size;
	  current_in_opcodeD = chid7_in_opcode;
	  current_in_message_startD = chid7_in_message_start;
	  current_in_message_linesD = chid7_in_message_lines;
	  current_in_message_idD = chid7_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[7];
	end
      
      8:
	begin
	  current_in_tailD = chid8_in_tail;
	  current_in_headD = chid8_out_head;
	  current_in_somD = chid8_in_som;
	  current_in_message_sizeD = chid8_in_message_size;
	  current_in_opcodeD = chid8_in_opcode;
	  current_in_message_startD = chid8_in_message_start;
	  current_in_message_linesD = chid8_in_message_lines;
	  current_in_message_idD = chid8_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[8];
	end
      
      9:
	begin
	  current_in_tailD = chid9_in_tail;
	  current_in_headD = chid9_out_head;
	  current_in_somD = chid9_in_som;
	  current_in_message_sizeD = chid9_in_message_size;
	  current_in_opcodeD = chid9_in_opcode;
	  current_in_message_startD = chid9_in_message_start;
	  current_in_message_linesD = chid9_in_message_lines;
	  current_in_message_idD = chid9_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[9];
	end
      
      10:
	begin
	  current_in_tailD = chid10_in_tail;
	  current_in_headD = chid10_out_head;
	  current_in_somD = chid10_in_som;
	  current_in_message_sizeD = chid10_in_message_size;
	  current_in_opcodeD = chid10_in_opcode;
	  current_in_message_startD = chid10_in_message_start;
	  current_in_message_linesD = chid10_in_message_lines;
	  current_in_message_idD = chid10_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[10];
	end
      
      11:
	begin
	  current_in_tailD = chid11_in_tail;
	  current_in_headD = chid11_out_head;
	  current_in_somD = chid11_in_som;
	  current_in_message_sizeD = chid11_in_message_size;
	  current_in_opcodeD = chid11_in_opcode;
	  current_in_message_startD = chid11_in_message_start;
	  current_in_message_linesD = chid11_in_message_lines;
	  current_in_message_idD = chid11_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[11];
	end
      
      12:
	begin
	  current_in_tailD = chid12_in_tail;
	  current_in_headD = chid12_out_head;
	  current_in_somD = chid12_in_som;
	  current_in_message_sizeD = chid12_in_message_size;
	  current_in_opcodeD = chid12_in_opcode;
	  current_in_message_startD = chid12_in_message_start;
	  current_in_message_linesD = chid12_in_message_lines;
	  current_in_message_idD = chid12_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[12];
	end
      
      13:
	begin
	  current_in_tailD = chid13_in_tail;
	  current_in_headD = chid13_out_head;
	  current_in_somD = chid13_in_som;
	  current_in_message_sizeD = chid13_in_message_size;
	  current_in_opcodeD = chid13_in_opcode;
	  current_in_message_startD = chid13_in_message_start;
	  current_in_message_linesD = chid13_in_message_lines;
	  current_in_message_idD = chid13_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[13];
	end
      
      14:
	begin
	  current_in_tailD = chid14_in_tail;
	  current_in_headD = chid14_out_head;
	  current_in_somD = chid14_in_som;
	  current_in_message_sizeD = chid14_in_message_size;
	  current_in_opcodeD = chid14_in_opcode;
	  current_in_message_startD = chid14_in_message_start;
	  current_in_message_linesD = chid14_in_message_lines;
	  current_in_message_idD = chid14_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[14];
	end
      
      15:
	begin
	  current_in_tailD = chid15_in_tail;
	  current_in_headD = chid15_out_head;
	  current_in_somD = chid15_in_som;
	  current_in_message_sizeD = chid15_in_message_size;
	  current_in_opcodeD = chid15_in_opcode;
	  current_in_message_startD = chid15_in_message_start;
	  current_in_message_linesD = chid15_in_message_lines;
	  current_in_message_idD = chid15_in_message_id;
	  current_in_buffer_data_countD = chid_in_buffer_data_count[15];
	end
      
      default: begin
      end
    endcase
  end


  //channel_out (read) arguments selection
  always @(*) begin
    case (current_out_chid)
      0:
	begin
	  current_out_headD = chid0_out_head; // read_from pointer
	end
      1:
	begin
	  current_out_headD = chid1_out_head;
	end
      
      2:
	begin
	  current_out_headD = chid2_out_head;
	end
      
      3:
	begin
	  current_out_headD = chid3_out_head;
	end
      
      4:
	begin
	  current_out_headD = chid4_out_head;
	end
      
      5:
	begin
	  current_out_headD = chid5_out_head;
	end
      
      6:
	begin
	  current_out_headD = chid6_out_head;
	end
      
      7:
	begin
	  current_out_headD = chid7_out_head;
	end
      
      8:
	begin
	  current_out_headD = chid8_out_head;
	end
      
      9:
	begin
	  current_out_headD = chid9_out_head;
	end
      
      10:
	begin
	  current_out_headD = chid10_out_head;
	end
      
      11:
	begin
	  current_out_headD = chid11_out_head;
	end
      
      12:
	begin
	  current_out_headD = chid12_out_head;
	end
      
      13:
	begin
	  current_out_headD = chid13_out_head;
	end
      
      14:
	begin
	  current_out_headD = chid14_out_head;
	end
      
      15:
	begin
	  current_out_headD = chid15_out_head;
	end
      
      default: begin
      end
    endcase
  end

  
  //zuc module fifo_in arguments selection
  always @(*) begin
    case (current_fifo_in_id)
      0:
	begin
	  fifo_in_readyD = fifo_in_ready[0];
	end
      1:
	begin
	  fifo_in_readyD = fifo_in_ready[1];
	end
      
      2:
	begin
	  fifo_in_readyD = fifo_in_ready[2];
	end
      
      3:
	begin
	  fifo_in_readyD = fifo_in_ready[3];
	end

      4:
	begin
	  fifo_in_readyD = fifo_in_ready[4];
	end
      5:
	begin
	  fifo_in_readyD = fifo_in_ready[5];
	end
      
      6:
	begin
	  fifo_in_readyD = fifo_in_ready[6];
	end
      
      7:
	begin
	  fifo_in_readyD = fifo_in_ready[7];
	end
      
      default: begin
      end
    endcase
  end

  
// channel_in (write) & channel_out (read) arguments update
  always @(posedge clk) begin
    if (reset || afu_reset) begin
      // head & tail & message_start of all channels are intialized to the beginning of the per-channel buffer
      ////  for (i = 0, i < NUM_CHANNELS ; i++)
      ////     chidx_tail <= {i[3:0], LOG(CHANNEL_BUFFER_SIZE)'b0}; // chid is the index to the channel buffer in input RAM
      // som is set to indicate that at the beginning, all chaneel buffers are empty, thus the next incoming packet is obviously a message start
      chid0_out_head <= {4'h0, 9'h000};
      chid0_in_tail <= {4'h0, 9'h000};
      chid0_in_message_start <= {4'h0, 9'h000};
      chid0_in_som <= 1'b1;
      chid0_in_message_id <= 12'h000;
      chid0_in_message_lines <= 10'h000;

      // message_count is a common register to both write & read operations, so no need for an in/out identifier
      // Unsigned count, max 256 messages/channel: 512 (=8K/16) entries/channel, minimum 1024b/message
      // Both input_buffer write & read state machines affect this count register
      chid1_out_head <= {4'h1, 9'h000};
      chid1_in_tail <= {4'h1, 9'h000};
      chid1_in_message_start <= {4'h1, 9'h000};
      chid1_in_som <= 1'b1;
      chid1_in_message_id <= 12'h000;
      chid1_in_message_lines <= 10'h000;
      chid2_out_head <= {4'h2, 9'b0};
      chid2_in_tail <= {4'h2, 9'b0};
      chid2_in_message_start <= {4'h2, 9'b0};
      chid2_in_som <= 1'b1;
      chid2_in_message_id <= 12'h000;
      chid2_in_message_lines <= 10'h000;
      chid3_out_head <= {4'h3, 9'b0};
      chid3_in_tail <= {4'h3, 9'b0};
      chid3_in_message_start <= {4'h3, 9'b0};
      chid3_in_som <= 1'b1;
      chid3_in_message_id <= 12'h000;
      chid3_in_message_lines <= 10'h000;
      chid4_out_head <= {4'h4, 9'b0};
      chid4_in_tail <= {4'h4, 9'b0};
      chid4_in_message_start <= {4'h4, 9'b0};
      chid4_in_som <= 1'b1;
      chid4_in_message_id <= 12'h000;
      chid4_in_message_lines <= 10'h000;
      chid5_out_head <= {4'h5, 9'b0};
      chid5_in_tail <= {4'h5, 9'b0};
      chid5_in_message_start <= {4'h5, 9'b0};
      chid5_in_som <= 1'b1;
      chid5_in_message_id <= 12'h000;
      chid5_in_message_lines <= 10'h000;
      chid6_out_head <= {4'h6, 9'b0};
      chid6_in_tail <= {4'h6, 9'b0};
      chid6_in_message_start <= {4'h6, 9'b0};
      chid6_in_som <= 1'b1;
      chid6_in_message_id <= 12'h000;
      chid6_in_message_lines <= 10'h000;
      chid7_out_head <= {4'h7, 9'b0};
      chid7_in_tail <= {4'h7, 9'b0};
      chid7_in_message_start <= {4'h7, 9'b0};
      chid7_in_som <= 1'b1;
      chid7_in_message_id <= 12'h000;
      chid7_in_message_lines <= 10'h000;
      chid8_out_head <= {4'h8, 9'b0};
      chid8_in_tail <= {4'h8, 9'b0};
      chid8_in_message_start <= {4'h8, 9'b0};
      chid8_in_som <= 1'b1;
      chid8_in_message_id <= 12'h000;
      chid8_in_message_lines <= 10'h000;
      chid9_out_head <= {4'h9, 9'b0};
      chid9_in_tail <= {4'h9, 9'b0};
      chid9_in_message_start <= {4'h9, 9'b0};
      chid9_in_som <= 1'b1;
      chid9_in_message_id <= 12'h000;
      chid9_in_message_lines <= 10'h000;
      chid10_out_head <= {4'ha, 9'b0};
      chid10_in_tail <= {4'ha, 9'b0};
      chid10_in_message_start <= {4'ha, 9'b0};
      chid10_in_som <= 1'b1;
      chid10_in_message_id <= 12'h000;
      chid10_in_message_lines <= 10'h000;
      chid11_out_head <= {4'hb, 9'b0};
      chid11_in_tail <= {4'hb, 9'b0};
      chid11_in_message_start <= {4'hb, 9'b0};
      chid11_in_som <= 1'b1;
      chid11_in_message_id <= 12'h000;
      chid11_in_message_lines <= 10'h000;
      chid12_out_head <= {4'hc, 9'b0};
      chid12_in_tail <= {4'hc, 9'b0};
      chid12_in_message_start <= {4'hc, 9'b0};
      chid12_in_som <= 1'b1;
      chid12_in_message_id <= 12'h000;
      chid12_in_message_lines <= 10'h000;
      chid13_out_head <= {4'hd, 9'b0};
      chid13_in_tail <= {4'hd, 9'b0};
      chid13_in_message_start <= {4'hd, 9'b0};
      chid13_in_som <= 1'b1;
      chid13_in_message_id <= 12'h000;
      chid13_in_message_lines <= 10'h000;
      chid14_out_head <= {4'he, 9'b0};
      chid14_in_tail <= {4'he, 9'b0};
      chid14_in_message_start <= {4'he, 9'b0};
      chid14_in_som <= 1'b1;
      chid14_in_message_id <= 12'h000;
      chid14_in_message_lines <= 10'h000;
      chid15_out_head <= {4'hf, 9'b0};
      chid15_in_tail <= {4'hf, 9'b0};
      chid15_in_message_start <= {4'hf, 9'b0};
      chid15_in_som <= 1'b1;
      chid15_in_message_id <= 12'h000;
      chid15_in_message_lines <= 10'h000;

      // Accumulated in_mesage_count
      // Stuck at max_count
      // Cleared when read via axi_lite (to be implemented)
      total_chid0_in_message_count <= 32'b0;
      total_chid1_in_message_count <= 32'b0;
      total_chid2_in_message_count <= 32'b0;
      total_chid3_in_message_count <= 32'b0;
      total_chid4_in_message_count <= 32'b0;
      total_chid5_in_message_count <= 32'b0;
      total_chid6_in_message_count <= 32'b0;
      total_chid7_in_message_count <= 32'b0;
      total_chid8_in_message_count <= 32'b0;
      total_chid9_in_message_count <= 32'b0;
      total_chid10_in_message_count <= 32'b0;
      total_chid11_in_message_count <= 32'b0;
      total_chid12_in_message_count <= 32'b0;
      total_chid13_in_message_count <= 32'b0;
      total_chid14_in_message_count <= 32'b0;
      total_chid15_in_message_count <= 32'b0;
      total_in_message_count <= 64'b0;
    end
    
    else begin
      if (update_channel_in_regs)
	// Updating channel_in registers
	// This indication also used in message_out state machine to increment a per-channel message_count
	begin
	  // Update occurs after a packet receive has completed, during either of the states:
	  // PACKET_IN_IDLE,PACKET_IN_PROGRESS, PACKET_IN_EOM
	  // In case of back-to-back packets, current_in_chid will last for 1 clock only, but this should be enough for this update
	  if (current_in_eom)
	    total_in_message_count <= total_in_message_count + 1;

	  case (current_in_chid)
	    0:
	      begin
		chid0_in_tail <= current_in_tail;
		chid0_in_message_start <= current_in_message_start;
		chid0_in_message_lines <= current_in_message_lines;
		chid0_in_som <= current_in_som;
		chid0_in_message_size <= current_in_message_size;
		chid0_in_opcode <= current_in_opcode;

		if (current_in_eom) begin
		  // These variables are updated only upon end_of_message
		  chid0_in_message_id <= current_in_message_id;
		  
		  // Message count is not incremented if there are both inc and dec request at the same time
		  total_chid0_in_message_count <= total_chid0_in_message_count + 1;
		  
		end
	      end
	    1:
	      begin
		chid1_in_tail <= current_in_tail;
		chid1_in_message_start <= current_in_message_start;
		chid1_in_message_lines <= current_in_message_lines;
		chid1_in_som <= current_in_som;
		chid1_in_message_size <= current_in_message_size;
		chid1_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid1_in_message_id <= current_in_message_id;
		  total_chid1_in_message_count <= total_chid1_in_message_count + 1;
		end
	      end
	    
	    2:
	      begin
		chid2_in_tail <= current_in_tail;
		chid2_in_message_start <= current_in_message_start;
		chid2_in_message_lines <= current_in_message_lines;
		chid2_in_som <= current_in_som;
		chid2_in_message_size <= current_in_message_size;
		chid2_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid2_in_message_id <= current_in_message_id;
		  total_chid2_in_message_count <= total_chid2_in_message_count + 1;
		end
	      end
	    
	    3:
	      begin
		chid3_in_tail <= current_in_tail;
		chid3_in_message_start <= current_in_message_start;
		chid3_in_message_lines <= current_in_message_lines;
		chid3_in_som <= current_in_som;
		chid3_in_message_size <= current_in_message_size;
		chid3_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid3_in_message_id <= current_in_message_id;
		  total_chid3_in_message_count <= total_chid3_in_message_count + 1;
		end
	      end
	    
	    4:
	      begin
		chid4_in_tail <= current_in_tail;
		chid4_in_message_start <= current_in_message_start;
		chid4_in_message_lines <= current_in_message_lines;
		chid4_in_som <= current_in_som;
		chid4_in_message_size <= current_in_message_size;
		chid4_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid4_in_message_id <= current_in_message_id;
		  total_chid4_in_message_count <= total_chid4_in_message_count + 1;
		end
	      end
	    
	    5:
	      begin
		chid5_in_tail <= current_in_tail;
		chid5_in_message_start <= current_in_message_start;
		chid5_in_message_lines <= current_in_message_lines;
		chid5_in_som <= current_in_som;
		chid5_in_message_size <= current_in_message_size;
		chid5_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid5_in_message_id <= current_in_message_id;
		  total_chid5_in_message_count <= total_chid5_in_message_count + 1;
		end
	      end
	    
	    6:
	      begin
		chid6_in_tail <= current_in_tail;
		chid6_in_message_start <= current_in_message_start;
		chid6_in_message_lines <= current_in_message_lines;
		chid6_in_som <= current_in_som;
		chid6_in_message_size <= current_in_message_size;
		chid6_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid6_in_message_id <= current_in_message_id;
		  total_chid6_in_message_count <= total_chid6_in_message_count + 1;
		end
	      end
	    
	    7:
	      begin
		chid7_in_tail <= current_in_tail;
		chid7_in_message_start <= current_in_message_start;
		chid7_in_message_lines <= current_in_message_lines;
		chid7_in_som <= current_in_som;
		chid7_in_message_size <= current_in_message_size;
		chid7_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid7_in_message_id <= current_in_message_id;
		  total_chid7_in_message_count <= total_chid7_in_message_count + 1;
		end
	      end
	    
	    8:
	      begin
		chid8_in_tail <= current_in_tail;
		chid8_in_message_start <= current_in_message_start;
		chid8_in_message_lines <= current_in_message_lines;
		chid8_in_som <= current_in_som;
		chid8_in_message_size <= current_in_message_size;
		chid8_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid8_in_message_id <= current_in_message_id;
		  total_chid8_in_message_count <= total_chid8_in_message_count + 1;
		end
	      end
	    
	    9:
	      begin
		chid9_in_tail <= current_in_tail;
		chid9_in_message_start <= current_in_message_start;
		chid9_in_message_lines <= current_in_message_lines;
		chid9_in_som <= current_in_som;
		chid9_in_message_size <= current_in_message_size;
		chid9_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid9_in_message_id <= current_in_message_id;
		  total_chid9_in_message_count <= total_chid9_in_message_count + 1;
		end
	      end
	    
	    10:
	      begin
		chid10_in_tail <= current_in_tail;
		chid10_in_message_start <= current_in_message_start;
		chid10_in_message_lines <= current_in_message_lines;
		chid10_in_som <= current_in_som;
		chid10_in_message_size <= current_in_message_size;
		chid10_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid10_in_message_id <= current_in_message_id;
		  total_chid10_in_message_count <= total_chid10_in_message_count + 1;
		end
	      end
	    
	    11:
	      begin
		chid11_in_tail <= current_in_tail;
		chid11_in_message_start <= current_in_message_start;
		chid11_in_message_lines <= current_in_message_lines;
		chid11_in_som <= current_in_som;
		chid11_in_message_size <= current_in_message_size;
		chid11_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid11_in_message_id <= current_in_message_id;
		  total_chid11_in_message_count <= total_chid11_in_message_count + 1;
		end
	      end
	    
	    12:
	      begin
		chid12_in_tail <= current_in_tail;
		chid12_in_message_start <= current_in_message_start;
		chid12_in_message_lines <= current_in_message_lines;
		chid12_in_som <= current_in_som;
		chid12_in_message_size <= current_in_message_size;
		chid12_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid12_in_message_id <= current_in_message_id;
		  total_chid12_in_message_count <= total_chid12_in_message_count + 1;
		end
	      end
	    
	    13:
	      begin
		chid13_in_tail <= current_in_tail;
		chid13_in_message_start <= current_in_message_start;
		chid13_in_message_lines <= current_in_message_lines;
		chid13_in_som <= current_in_som;
		chid13_in_message_size <= current_in_message_size;
		chid13_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid13_in_message_id <= current_in_message_id;
		  total_chid13_in_message_count <= total_chid13_in_message_count + 1;
		end
	      end
	    
	    14:
	      begin
		chid14_in_tail <= current_in_tail;
		chid14_in_message_start <= current_in_message_start;
		chid14_in_message_lines <= current_in_message_lines;
		chid14_in_som <= current_in_som;
		chid14_in_message_size <= current_in_message_size;
		chid14_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid14_in_message_id <= current_in_message_id;
		  total_chid14_in_message_count <= total_chid14_in_message_count + 1;
		end
	      end
	    
	    15:
	      begin
		chid15_in_tail <= current_in_tail;
		chid15_in_message_start <= current_in_message_start;
		chid15_in_message_lines <= current_in_message_lines;
		chid15_in_som <= current_in_som;
		chid15_in_message_size <= current_in_message_size;
		chid15_in_opcode <= current_in_opcode;
		if (current_in_eom) begin
		  chid15_in_message_id <= current_in_message_id;
		  total_chid15_in_message_count <= total_chid15_in_message_count + 1;
		end
	      end
	    
	    default: begin
	    end
	  endcase
	end

      if (update_channel_out_regs)
	// Updating channel_out registers
	begin
	  // Update occurs after a complete message has been read from buffer
	  case (current_out_chid)
	    0:
	      begin
		chid0_out_head <= current_out_head;
		chid0_out_som <= current_out_som;
	      end
	    1:
	      begin
		chid1_out_head <= current_out_head;
		chid1_out_som <= current_out_som;
	      end
	    
	    2:
	      begin
		chid2_out_head <= current_out_head;
		chid2_out_som <= current_out_som;
	      end
	    
	    3:
	      begin
		chid3_out_head <= current_out_head;
		chid3_out_som <= current_out_som;
	      end
	    
	    4:
	      begin
		chid4_out_head <= current_out_head;
		chid4_out_som <= current_out_som;
	      end
	    
	    5:
	      begin
		chid5_out_head <= current_out_head;
		chid5_out_som <= current_out_som;
	      end
	    
	    6:
	      begin
		chid6_out_head <= current_out_head;
		chid6_out_som <= current_out_som;
	      end
	    
	    7:
	      begin
		chid7_out_head <= current_out_head;
		chid7_out_som <= current_out_som;
	      end
	    
	    8:
	      begin
		chid8_out_head <= current_out_head;
		chid8_out_som <= current_out_som;
	      end
	    
	    9:
	      begin
		chid9_out_head <= current_out_head;
		chid9_out_som <= current_out_som;
	      end
	    
	    10:
	      begin
		chid10_out_head <= current_out_head;
		chid10_out_som <= current_out_som;
	      end
	    
	    11:
	      begin
		chid11_out_head <= current_out_head;
		chid11_out_som <= current_out_som;
	      end
	    
	    12:
	      begin
		chid12_out_head <= current_out_head;
		chid12_out_som <= current_out_som;
	      end
	    
	    13:
	      begin
		chid13_out_head <= current_out_head;
		chid13_out_som <= current_out_som;
	      end
	    
	    14:
	      begin
		chid14_out_head <= current_out_head;
		chid14_out_som <= current_out_som;
	      end
	    
	    15:
	      begin
		chid15_out_head <= current_out_head;
		chid15_out_som <= current_out_som;
	      end
	    
	    default: begin
	    end
	  endcase
	end
    end
  end  


  generate
  genvar k;
    // in_message_count[*] update:
    // Message count is unchanged if there is both inc and dec request at the same time
  for (k = 0; k < NUM_CHANNELS ; k = k + 1) begin: in_message_counters
    always @(posedge clk) 
      begin
	if (reset || afu_reset) 
	  begin
	    chid_in_message_count[k] <= 10'h000;
	  end
	else 
	  begin
	  if ((current_in_eom && update_channel_in_regs && (current_in_chid == k)) && ~(update_channel_out_regs && (current_out_chid == k)))
	    chid_in_message_count[k] <= chid_in_message_count[k] + 1'b1;
	  else if (~(current_in_eom && update_channel_in_regs && (current_in_chid == k)) && (update_channel_out_regs && (current_out_chid == k)))
	    chid_in_message_count[k] <= chid_in_message_count[k] - 1'b1;
	  end
      end  
  end
  endgenerate


// fifox_in_total_load calculation:
  wire [2:0] update_fifo0_in_load;
  wire [2:0] update_fifo1_in_load;
  wire [2:0] update_fifo2_in_load;
  wire [2:0] update_fifo3_in_load;
  wire [2:0] update_fifo4_in_load;
  wire [2:0] update_fifo5_in_load;
  wire [2:0] update_fifo6_in_load;
  wire [2:0] update_fifo7_in_load;
  wire [15:0] current_fifo_in_message_load;
  wire [15:0] current_fifo_in_message_overhead;
  wire [15:0] current_zuc0_flit_overhead;
  wire [15:0] current_zuc0_message_overhead;
  wire [15:0] current_zuc1_flit_overhead;
  wire [15:0] current_zuc1_message_overhead;
  wire [15:0] current_zuc2_flit_overhead;
  wire [15:0] current_zuc2_message_overhead;
  wire [15:0] current_zuc3_flit_overhead;
  wire [15:0] current_zuc3_message_overhead;
  wire [15:0] current_zuc4_flit_overhead;
  wire [15:0] current_zuc4_message_overhead;
  wire [15:0] current_zuc5_flit_overhead;
  wire [15:0] current_zuc5_message_overhead;
  wire [15:0] current_zuc6_flit_overhead;
  wire [15:0] current_zuc6_message_overhead;
  wire [15:0] current_zuc7_flit_overhead;
  wire [15:0] current_zuc7_message_overhead;

  assign update_fifo0_in_load = {update_fifo_in_regs && (current_fifo_in_id == 3'b000), zuc_progress[0][1:0]};
  assign update_fifo1_in_load = {update_fifo_in_regs && (current_fifo_in_id == 3'b001), zuc_progress[1][1:0]};
  assign update_fifo2_in_load = {update_fifo_in_regs && (current_fifo_in_id == 3'b010), zuc_progress[2][1:0]};
  assign update_fifo3_in_load = {update_fifo_in_regs && (current_fifo_in_id == 3'b011), zuc_progress[3][1:0]};
  assign update_fifo4_in_load = {update_fifo_in_regs && (current_fifo_in_id == 3'b100), zuc_progress[4][1:0]};
  assign update_fifo5_in_load = {update_fifo_in_regs && (current_fifo_in_id == 3'b101), zuc_progress[5][1:0]};
  assign update_fifo6_in_load = {update_fifo_in_regs && (current_fifo_in_id == 3'b110), zuc_progress[6][1:0]};
  assign update_fifo7_in_load = {update_fifo_in_regs && (current_fifo_in_id == 3'b111), zuc_progress[7][1:0]};
  assign current_fifo_in_message_overhead = (current_fifo_in_message_cmd == MESSAGE_CMD_INTEG) ? 16'h002e :        // I message overhead: 46 clocks
					    (current_fifo_in_message_cmd == MESSAGE_CMD_CONF) ? 16'h002c :         // I message overhead: 44 clocks 
					    (current_fifo_in_message_cmd == MESSAGE_CMD_MODULEBYPASS) ? 16'h0006 : // MODULEBYPASS message overhead: 6 clocks
					    16'h0000;

  assign current_fifo_in_message_load = (current_fifo_in_message_cmd == MESSAGE_CMD_MODULEBYPASS) ?
					(current_fifo_in_message_lines + 1) + current_fifo_in_message_overhead : // In bypass, header line should be added 
					(current_fifo_in_message_words) + current_fifo_in_message_overhead;

  assign current_zuc0_flit_overhead = ({4'h0, zuc_progress[0][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0001 : {8'h00, zuc_progress[0][15:8]};
  assign current_zuc0_message_overhead = ({4'h0, zuc_progress[0][7:4]} == MESSAGE_CMD_INTEG) ? 16'h002e : // 46 clocks overhead per I message 
					    ({4'h0, zuc_progress[0][7:4]} == MESSAGE_CMD_CONF) ? 16'h002c : // 44 clocks overhead per C message 
					    ({4'h0, zuc_progress[0][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0006 : // 6 clocks overhead per MODULEBYPASS message 
					    16'h0000;
  assign current_zuc1_flit_overhead = ({4'h0, zuc_progress[1][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0001 : {8'h00, zuc_progress[1][15:8]};
  assign current_zuc1_message_overhead = ({4'h0, zuc_progress[1][7:4]} == MESSAGE_CMD_INTEG) ? 16'h002e : // 46 clocks overhead per I message 
					    ({4'h0, zuc_progress[1][7:4]} == MESSAGE_CMD_CONF) ? 16'h002c : // 44 clocks overhead per C message 
					    ({4'h0, zuc_progress[1][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0006 : // 6 clocks overhead per MODULEBYPASS message 
					    16'h0000;
  assign current_zuc2_flit_overhead = ({4'h0, zuc_progress[2][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0001 : {8'h00, zuc_progress[2][15:8]};
  assign current_zuc2_message_overhead = ({4'h0, zuc_progress[2][7:4]} == MESSAGE_CMD_INTEG) ? 16'h002e : // 46 clocks overhead per I message 
					    ({4'h0, zuc_progress[2][7:4]} == MESSAGE_CMD_CONF) ? 16'h002c : // 44 clocks overhead per C message 
					    ({4'h0, zuc_progress[2][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0006 : // 6 clocks overhead per MODULEBYPASS message 
					    16'h0000;
  assign current_zuc3_flit_overhead = ({4'h0, zuc_progress[3][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0001 : {8'h00, zuc_progress[3][15:8]};
  assign current_zuc3_message_overhead = ({4'h0, zuc_progress[3][7:4]} == MESSAGE_CMD_INTEG) ? 16'h002e : // 46 clocks overhead per I message 
					    ({4'h0, zuc_progress[3][7:4]} == MESSAGE_CMD_CONF) ? 16'h002c : // 44 clocks overhead per C message 
					    ({4'h0, zuc_progress[3][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0006 : // 6 clocks overhead per MODULEBYPASS message 
					    16'h0000;
  assign current_zuc4_flit_overhead = ({4'h0, zuc_progress[4][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0001 : {8'h00, zuc_progress[4][15:8]};
  assign current_zuc4_message_overhead = ({4'h0, zuc_progress[4][7:4]} == MESSAGE_CMD_INTEG) ? 16'h002e : // 46 clocks overhead per I message 
					    ({4'h0, zuc_progress[4][7:4]} == MESSAGE_CMD_CONF) ? 16'h002c : // 44 clocks overhead per C message 
					    ({4'h0, zuc_progress[4][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0006 : // 6 clocks overhead per MODULEBYPASS message 
					    16'h0000;
  assign current_zuc5_flit_overhead = ({4'h0, zuc_progress[5][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0001 : {8'h00, zuc_progress[5][15:8]};
  assign current_zuc5_message_overhead = ({4'h0, zuc_progress[5][7:4]} == MESSAGE_CMD_INTEG) ? 16'h002e : // 46 clocks overhead per I message 
					    ({4'h0, zuc_progress[5][7:4]} == MESSAGE_CMD_CONF) ? 16'h002c : // 44 clocks overhead per C message 
					    ({4'h0, zuc_progress[5][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0006 : // 6 clocks overhead per MODULEBYPASS message 
					    16'h0000;
  assign current_zuc6_flit_overhead = ({4'h0, zuc_progress[6][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0001 : {8'h00, zuc_progress[6][15:8]};
  assign current_zuc6_message_overhead = ({4'h0, zuc_progress[6][7:4]} == MESSAGE_CMD_INTEG) ? 16'h002e : // 46 clocks overhead per I message 
					    ({4'h0, zuc_progress[6][7:4]} == MESSAGE_CMD_CONF) ? 16'h002c : // 44 clocks overhead per C message 
					    ({4'h0, zuc_progress[6][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0006 : // 6 clocks overhead per MODULEBYPASS message 
					    16'h0000;
  assign current_zuc7_flit_overhead = ({4'h0, zuc_progress[7][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0001 : {8'h00, zuc_progress[7][15:8]};
  assign current_zuc7_message_overhead = ({4'h0, zuc_progress[7][7:4]} == MESSAGE_CMD_INTEG) ? 16'h002e : // 46 clocks overhead per I message 
					    ({4'h0, zuc_progress[7][7:4]} == MESSAGE_CMD_CONF) ? 16'h002c : // 44 clocks overhead per C message 
					    ({4'h0, zuc_progress[7][7:4]} == MESSAGE_CMD_MODULEBYPASS) ? 16'h0006 : // 6 clocks overhead per MODULEBYPASS message 
					    16'h0000;

  
  always @(posedge clk) begin
    if (reset || afu_reset) begin
      fifo0_in_message_count <= 0;
      fifo1_in_message_count <= 0;
      fifo2_in_message_count <= 0;
      fifo3_in_message_count <= 0;
      fifo4_in_message_count <= 0;
      fifo5_in_message_count <= 0;
      fifo6_in_message_count <= 0;
      fifo7_in_message_count <= 0;
      fifo0_in_total_load <= 0;
      fifo1_in_total_load <= 0;
      fifo2_in_total_load <= 0;
      fifo3_in_total_load <= 0;
      fifo4_in_total_load <= 0;
      fifo5_in_total_load <= 0;
      fifo6_in_total_load <= 0;
      fifo7_in_total_load <= 0;
    end
    else begin
      // Update fifo0_in message count:
      // 1. Increment if loaded with a new message from input_buffer
      // 2. Decrement if a message read to zuc0 module
      // 3. Do nothing, if both 1 & 2 occur at the same time
      if (update_fifo_in_regs && (current_fifo_in_id == 3'b000) && ~update_zuc_module_regs[0])
	fifo0_in_message_count <= fifo0_in_message_count + 1;
      else if (~(update_fifo_in_regs && (current_fifo_in_id == 3'b000)) && update_zuc_module_regs[0])
	fifo0_in_message_count <= fifo0_in_message_count - 1;
      // else, do nothing
      
      if (update_fifo_in_regs && (current_fifo_in_id == 3'b001) && ~update_zuc_module_regs[1])
	fifo1_in_message_count <= fifo1_in_message_count + 1;
      else if (~(update_fifo_in_regs && (current_fifo_in_id == 3'b001)) && update_zuc_module_regs[1])
	fifo1_in_message_count <= fifo1_in_message_count - 1;

      if (update_fifo_in_regs && (current_fifo_in_id == 3'b010) && ~update_zuc_module_regs[2])
	fifo2_in_message_count <= fifo2_in_message_count + 1;
      else if (~(update_fifo_in_regs && (current_fifo_in_id == 3'b010)) && update_zuc_module_regs[2])
	fifo2_in_message_count <= fifo2_in_message_count - 1;

      if (update_fifo_in_regs && (current_fifo_in_id == 3'b011) && ~update_zuc_module_regs[3])
	fifo3_in_message_count <= fifo3_in_message_count + 1;
      else if (~(update_fifo_in_regs && (current_fifo_in_id == 3'b011)) && update_zuc_module_regs[3])
	fifo3_in_message_count <= fifo3_in_message_count - 1;

      if (update_fifo_in_regs && (current_fifo_in_id == 3'b100) && ~update_zuc_module_regs[4])
	fifo4_in_message_count <= fifo4_in_message_count + 1;
      else if (~(update_fifo_in_regs && (current_fifo_in_id == 3'b100)) && update_zuc_module_regs[4])
	fifo4_in_message_count <= fifo4_in_message_count - 1;
      
      if (update_fifo_in_regs && (current_fifo_in_id == 3'b101) && ~update_zuc_module_regs[5])
	fifo5_in_message_count <= fifo5_in_message_count + 1;
      else if (~(update_fifo_in_regs && (current_fifo_in_id == 3'b101)) && update_zuc_module_regs[5])
	fifo5_in_message_count <= fifo5_in_message_count - 1;

      if (update_fifo_in_regs && (current_fifo_in_id == 3'b110) && ~update_zuc_module_regs[6])
	fifo6_in_message_count <= fifo6_in_message_count + 1;
      else if (~(update_fifo_in_regs && (current_fifo_in_id == 3'b110)) && update_zuc_module_regs[6])
	fifo6_in_message_count <= fifo6_in_message_count - 1;

      if (update_fifo_in_regs && (current_fifo_in_id == 3'b111) && ~update_zuc_module_regs[7])
	fifo7_in_message_count <= fifo7_in_message_count + 1;
      else if (~(update_fifo_in_regs && (current_fifo_in_id == 3'b111)) && update_zuc_module_regs[7])
	fifo7_in_message_count <= fifo7_in_message_count - 1;


      // fifox_in total load calculation:
      case (update_fifo0_in_load)
	0:
	  begin
	    // Do nothing
	  end
	1:
	  begin
	    // Another message overhead is done by zuc0
	    fifo0_in_total_load <= fifo0_in_total_load - current_zuc0_message_overhead;
	  end
	
	2:
	  begin
	    // Message overhead is done by zuc0
	    fifo0_in_total_load <= fifo0_in_total_load - current_zuc0_flit_overhead;
	  end
	3:
	  begin
	    // Reserved. Do nothing
	  end
	4:
	  begin
	    // A new message have been loaded to fifo0_in
	    fifo0_in_total_load <= fifo0_in_total_load + current_fifo_in_message_load;
	  end
	5:
	  begin
	    // A new message have been loaded to fifo0_in, along with zuc0 done with a message_overhead
	    fifo0_in_total_load <= fifo0_in_total_load + current_fifo_in_message_load - current_zuc0_message_overhead;
	  end
	6:
	  begin
	    // A new message have been loaded to fifo0_in, along with zuc0 done with another flit
	    fifo0_in_total_load <= fifo0_in_total_load + current_fifo_in_message_load - current_zuc0_flit_overhead;
	  end
	7:
	  begin
	    // Impossible case, do nothing
	  end
	
	default: begin
	end
      endcase

      case (update_fifo1_in_load)
	0:
	  begin
	  end
	1:
	  begin
	    fifo1_in_total_load <= fifo1_in_total_load - current_zuc1_message_overhead;
	  end
	
	2:
	  begin
	    fifo1_in_total_load <= fifo1_in_total_load - current_zuc1_flit_overhead;
	  end
	3:
	  begin
	  end
	4:
	  begin
	    fifo1_in_total_load <= fifo1_in_total_load + current_fifo_in_message_load;
	  end
	5:
	  begin
	    fifo1_in_total_load <= fifo1_in_total_load + current_fifo_in_message_load - current_zuc1_message_overhead;
	  end
	6:
	  begin
	    fifo1_in_total_load <= fifo1_in_total_load + current_fifo_in_message_load - current_zuc1_flit_overhead;
	  end
	7:
	  begin
	  end
	
	default: begin
	end
      endcase

      case (update_fifo2_in_load)
	0:
	  begin
	  end
	1:
	  begin
	    fifo2_in_total_load <= fifo2_in_total_load - current_zuc2_message_overhead;
	  end
	
	2:
	  begin
	    fifo2_in_total_load <= fifo2_in_total_load - current_zuc2_flit_overhead;
	  end
	3:
	  begin
	  end
	4:
	  begin
	    fifo2_in_total_load <= fifo2_in_total_load + current_fifo_in_message_load;
	  end
	5:
	  begin
	    fifo2_in_total_load <= fifo2_in_total_load + current_fifo_in_message_load - current_zuc2_message_overhead;
	  end
	6:
	  begin
	    fifo2_in_total_load <= fifo2_in_total_load + current_fifo_in_message_load - current_zuc2_flit_overhead;
	  end
	7:
	  begin
	  end
	
	default: begin
	end
      endcase

      case (update_fifo3_in_load)
	0:
	  begin
	  end
	1:
	  begin
	    fifo3_in_total_load <= fifo3_in_total_load - current_zuc3_message_overhead;
	  end
	
	2:
	  begin
	    fifo3_in_total_load <= fifo3_in_total_load - current_zuc3_flit_overhead;
	  end
	3:
	  begin
	  end
	4:
	  begin
	    fifo3_in_total_load <= fifo3_in_total_load + current_fifo_in_message_load;
	  end
	5:
	  begin
	    fifo3_in_total_load <= fifo3_in_total_load + current_fifo_in_message_load - current_zuc3_message_overhead;
	  end
	6:
	  begin
	    fifo3_in_total_load <= fifo3_in_total_load + current_fifo_in_message_load - current_zuc3_flit_overhead;
	  end
	7:
	  begin
	  end

	
	default: begin
	end
      endcase

      case (update_fifo4_in_load)
	0:
	  begin
	    // Do nothing
	  end
	1:
	  begin
	    // Another message overhead is done by zuc0
	    fifo4_in_total_load <= fifo4_in_total_load - current_zuc4_message_overhead;
	  end
	
	2:
	  begin
	    // Message overhead is done by zuc0
	    fifo4_in_total_load <= fifo4_in_total_load - current_zuc4_flit_overhead;
	  end
	3:
	  begin
	    // Reserved. Do nothing
	  end
	4:
	  begin
	    // A new message have been loaded to fifo0_in
	    fifo4_in_total_load <= fifo4_in_total_load + current_fifo_in_message_load;
	  end
	5:
	  begin
	    // A new message have been loaded to fifo0_in, along with zuc0 done with a message_overhead
	    fifo4_in_total_load <= fifo4_in_total_load + current_fifo_in_message_load - current_zuc4_message_overhead;
	  end
	6:
	  begin
	    // A new message have been loaded to fifo0_in, along with zuc0 done with another flit
	    fifo4_in_total_load <= fifo4_in_total_load + current_fifo_in_message_load - current_zuc4_flit_overhead;
	  end
	7:
	  begin
	    // Impossible case, do nothing
	  end
	
	default: begin
	end
      endcase

      case (update_fifo5_in_load)
	0:
	  begin
	  end
	1:
	  begin
	    fifo5_in_total_load <= fifo5_in_total_load - current_zuc5_message_overhead;
	  end
	
	2:
	  begin
	    fifo5_in_total_load <= fifo5_in_total_load - current_zuc5_flit_overhead;
	  end
	3:
	  begin
	  end
	4:
	  begin
	    fifo5_in_total_load <= fifo5_in_total_load + current_fifo_in_message_load;
	  end
	5:
	  begin
	    fifo5_in_total_load <= fifo5_in_total_load + current_fifo_in_message_load - current_zuc5_message_overhead;
	  end
	6:
	  begin
	    fifo5_in_total_load <= fifo5_in_total_load + current_fifo_in_message_load - current_zuc5_flit_overhead;
	  end
	7:
	  begin
	  end
	
	default: begin
	end
      endcase

      case (update_fifo6_in_load)
	0:
	  begin
	  end
	1:
	  begin
	    fifo6_in_total_load <= fifo6_in_total_load - current_zuc6_message_overhead;
	  end
	
	2:
	  begin
	    fifo6_in_total_load <= fifo6_in_total_load - current_zuc6_flit_overhead;
	  end
	3:
	  begin
	  end
	4:
	  begin
	    fifo6_in_total_load <= fifo6_in_total_load + current_fifo_in_message_load;
	  end
	5:
	  begin
	    fifo6_in_total_load <= fifo6_in_total_load + current_fifo_in_message_load - current_zuc6_message_overhead;
	  end
	6:
	  begin
	    fifo6_in_total_load <= fifo6_in_total_load + current_fifo_in_message_load - current_zuc6_flit_overhead;
	  end
	7:
	  begin
	  end
	
	default: begin
	end
      endcase

      case (update_fifo7_in_load)
	0:
	  begin
	  end
	1:
	  begin
	    fifo7_in_total_load <= fifo7_in_total_load - current_zuc7_message_overhead;
	  end
	
	2:
	  begin
	    fifo7_in_total_load <= fifo7_in_total_load - current_zuc7_flit_overhead;
	  end
	3:
	  begin
	  end
	4:
	  begin
	    fifo7_in_total_load <= fifo7_in_total_load + current_fifo_in_message_load;
	  end
	5:
	  begin
	    fifo7_in_total_load <= fifo7_in_total_load + current_fifo_in_message_load - current_zuc7_message_overhead;
	  end
	6:
	  begin
	    fifo7_in_total_load <= fifo7_in_total_load + current_fifo_in_message_load - current_zuc7_flit_overhead;
	  end
	7:
	  begin
	  end
	
	default: begin
	end
      endcase

    end
  end


  // input_buffer full/empty indication:
  // Calculated per channel.
  // buffer full means less than 4 lines left in current_buffer
  assign current_in_buffer_full = (current_in_buffer_data_countD >= CHANNEL_BUFFER_MAX_CAPACITY) ? 1'b1 : 1'b0;
  //(current_in_tail >= current_in_headD) ?
  //  				   (current_in_tail - current_in_headD) >= (CHANNEL_BUFFER_MAX_CAPACITY) :
  //  				   (current_in_headD - current_in_tail) <= CHANNEL_BUFFER_SIZE_WATERMARK;
generate
  genvar j;
  for (j = 0; j < NUM_CHANNELS ; j = j + 1) begin: input_buffers_counters
    always @(posedge clk) begin
      if (reset || afu_reset) begin
	chid_in_buffer_data_count[j] <= 11'h000;
      end
      
      else begin
	if ((current_in_chid == j) && (current_out_chid == j))
	  // Check for concurrent inc & dec of same counter
	  begin 
	    if (current_in_tail_incremented && ~current_out_head_incremented)
		chid_in_buffer_data_count[j] <= chid_in_buffer_data_count[j] + 1'b1;
	    else if (~current_in_tail_incremented && current_out_head_incremented)
		chid_in_buffer_data_count[j] <= chid_in_buffer_data_count[j] - 1'b1;
	      // else do nothing
	  end

	else if (current_in_chid == j)
	  // Check for increment only:
	  begin 
	    if (current_in_tail_incremented)
	      chid_in_buffer_data_count[j] <= chid_in_buffer_data_count[j] + 1'b1;
	  end

	else if (current_out_chid == j)
	  // Check for decrement only:
	  begin 
	    if (current_out_head_incremented)
	      chid_in_buffer_data_count[j] <= chid_in_buffer_data_count[j] - 1'b1;
	  end

	chid_in_buffer_not_empty[j] <= chid_in_buffer_data_count[j] > 10'h0000;
      end
    end  
  end
endgenerate


//  assign current_in_zuccmd = module_in_force_modulebypass ? 1'b0 : (current_in_opcode  == MESSAGE_CMD_CONF) || (current_in_opcode  == MESSAGE_CMD_INTEG);
  assign current_in_zuccmd = (current_in_opcode  == MESSAGE_CMD_CONF) || (current_in_opcode  == MESSAGE_CMD_INTEG);
  assign current_in_illegal_cmd = (current_in_opcode > 8'h03);

  wire [9:0] current_in_flits1, current_in_flits2, current_in_flits;
  
  assign current_in_flits1 = (current_in_message_size & 16'hffc0) >> 6;
  assign current_in_flits2 = (current_in_message_size & 16'h003f) > 0 ? 1 : 0;
  assign current_in_flits = current_in_flits1 + current_in_flits2;
  

  // input_buffer watermark (see afu_ctrl0[9:0] configuration):
  // Since the watermark logic is handled outside the packet_in* SM, *watrmark_met is valid only if head and tail belong to current chid
  assign current_in_buffer_watermark_met = (current_in_buffer_data_countD >= input_buffer_watermark) ? 1'b1 : 1'b0;
  
  always @(posedge clk) begin
    if (reset || afu_reset) begin
      input_buffer_watermark_met <= 16'hffff; //Default: watermark is 'met' for all channels 
      input_buffer_watermark <= 10'h000;
    end

    else begin
      if (afu_ctrl0_wr)
	begin
	  input_buffer_watermark_met <= 16'h0000; // input_buffer watermark has been configured. All 'met' indications are cleared.
	  // Max watermark is limitted to 9'h1f0 == 496 (16 lines below the input buffer size):
	  input_buffer_watermark <= {1'b0, (afu_ctrl0[8:4] == 5'h1f) ? 9'h1f0 : afu_ctrl0[8:0]};
	end
      else
	begin
	  if (current_in_buffer_watermark_met)
	    // Check whether watermark has been met for current channel. If yes, set its 'met' indication
	    input_buffer_watermark_met <= input_buffer_watermark_met | (16'h0001 << current_in_chid);

	end
    end
  end  
  

  // Message_In State Machine: Message read from pci2sbu to local buffer:
  localparam [2:0]
    PACKET_IN_IDLE         = 3'b000,
    CHANNEL_IN_SELECT      = 3'b001,
    PACKET_IN_WRITE_ETH_HEADER = 3'b010,
    PACKET_IN_WRITE_HEADER = 3'b011,
    PACKET_IN_WRITE_STATUS = 3'b100,
    PACKET_IN_WAIT_WRITE   = 3'b101,
    PACKET_IN_PROGRESS     = 3'b110,
    PACKET_IN_EOM          = 3'b111;

  always @(posedge clk) begin
    if (reset || afu_reset) begin
      packet_in_nstate <= PACKET_IN_IDLE;
      current_in_message_ok <= 1'b0;
      pci2sbu_ready <= 0;
      update_channel_in_regs <= 0;
      current_in_chid <= 4'b0;
      current_in_tail <= 13'b0;
      current_in_tail_incremented <= 0;
      current_in_head <= 13'b0;
      current_in_eom <= 0;
      current_in_pkt_type <= 0;
      current_in_som <= 1;
      current_in_message_id <= 12'h000;  // message IDs per channel buffer: 256. Yet, the counter is 12 bits
      input_buffer_write <= 0;
      input_buffer_meta_write <= 0;
      input_buffer_wren <= 1'b1; // input buffer write port is enabled by default. TBD: Power optimization: Consider enabling upon need only
      write_eth_header = 1'b0;
      packet_in_progress <= 1'b0;
      current_in_message_status_update <= 1'b0;
      current_in_message_status <= 8'h00;
      hist_pci2sbu_packet_event <= 1'b0;
      hist_pci2sbu_eompacket_event <= 1'b0;
      hist_pci2sbu_message_event <= 1'b0;
    end

    else begin
      case (packet_in_nstate)
	PACKET_IN_IDLE:
	  // Waiting for next packet in input pci2sbu stream
	  begin
	    current_in_message_ok <= 1'b0;
	    input_buffer_write <= 0;
	    input_buffer_meta_write <= 0;
	    update_channel_in_regs <= 0;
	    pci2sbu_ready <= 0;
	    packet_in_progress <= 1'b0;
	    current_in_message_status <= 8'h00;
	    current_in_tail_incremented <= 1'b0;
	    
	    if (pci2sbu_axi4stream_vld)
	      begin
		// start of a new packet, not neccessarily the first of a message
		//
		// First line of a packet includes a meaningful TUSER data: Keep copy of relevant TUSER data, to be saved later to channel's context
		// Notice that we sample pci2sbu_axi4stream_tdata WITHOUT dropping this line from input stream (pci2sbu_ready not asserted).
		//
		// current_in_chid is used to select the current channel related variables, which are sampled at the following state (clock)

		// TBD: Consider current_in_context while choosing a channel to be serviced
		// TBD: Add a scheme to filter unrecognized packets 
		current_in_context <= pci2sbu_axi4stream_tuser[63:60];   // Message context
		current_in_chid <= pci2sbu_axi4stream_tuser[59:56];      // Message channel ID
		current_in_eom <= afu_ctrl0[28] ? 1'b1 : pci2sbu_axi4stream_tuser[39]; // End_Of_Message indication: 
		                                                         // Current packet is last packet of current message
		                                                         // Forced to '1, while EOM not implemented in FLD
		current_in_pkt_type <= pci2sbu_axi4stream_tuser[30];     // packet_type: 0: Ethernet, 1: DRMA RC
		packet_in_nstate <= CHANNEL_IN_SELECT;
	      end
	    
	  end // case: PACKET_IN_IDLE
	
	CHANNEL_IN_SELECT:
	  // A new packet is pending in pci2sbu, and we already know its destined channel
	  // Load the selected channel variables from the chidx_* array
	  // First packet line is still valid & pending in pci2sbu_axi4stream_tdata, nothing read so far
	  begin
	    current_in_message_id <= current_in_message_idD; // Holding the ID of the currently handled message
	    current_in_tail <= current_in_tailD;             // Both head and tail are required, for buffer_full calculation
	    current_in_head <= current_in_headD;
	    current_in_som <= current_in_somD;
	    current_in_message_start <= current_in_message_startD;
	    current_in_message_lines <= current_in_message_linesD;
	    current_in_mask_message_id <= ((afu_ctrl2[15:0] >> current_in_chid) & 16'h0001) > 0 ? 1'b1 : 1'b0;

	    // pci2sbu_packet_size update
	    hist_pci2sbu_packet_event_size <= 16'h0000;
	    hist_pci2sbu_packet_event_chid <= current_in_chid;
	    hist_pci2sbu_packet_event <= 1'b0;
	    hist_pci2sbu_eompacket_event_size <= 16'h0000;
	    hist_pci2sbu_eompacket_event_chid <= current_in_chid;
	    hist_pci2sbu_eompacket_event <= 1'b0;
	    hist_pci2sbu_message_event <= 1'b0;

	    // An Ethernet packet: Sample the header for a later header update
	    if (~current_in_pkt_type)
	      current_in_eth_header <= pci2sbu_axi4stream_tdata[511:176];

	    if (current_in_somD)
	      begin
		// Current packet is first in message of current chid.
		if (current_in_pkt_type)
		  begin
		    // An RDMA RC packet: Capture message size & opcode, and store the header to input buffer
		    current_in_message_size <= pci2sbu_axi4stream_tdata[495:480];
		    current_in_opcode <= pci2sbu_axi4stream_tdata[511:504];
		    packet_in_nstate <= PACKET_IN_WRITE_HEADER;
		  end
		else
		  begin
		    // An Ethernet packet: Message size & opcode will be captured from message header after dropping the Ethernet header.
		    packet_in_nstate <= PACKET_IN_WRITE_ETH_HEADER;
		  end
	      end
	    else
	      begin
		// Current packet is not the first of a message: read its length from channel context, independent of packet type
		current_in_message_size <= current_in_message_sizeD;
		current_in_opcode <= current_in_opcodeD;
		if (current_in_pkt_type)
		  begin
		    packet_in_progress <= 1'b1;
		    packet_in_nstate <= PACKET_IN_PROGRESS;
		  end
		else
		  packet_in_nstate <= PACKET_IN_WRITE_ETH_HEADER;
	      end
	  end
	
	PACKET_IN_WRITE_ETH_HEADER:
	  begin
	    if (current_in_som)
	      // Start of a message, store the eth header into input buffer
	      begin
		if (~current_in_buffer_full)
		  begin
		    write_eth_header = 1'b1;
		    input_buffer_write <= 1'b1;
		    input_buffer_meta_write <= 1'b1;
		    pci2sbu_ready <= 1'b1;
		    // 1-clock write settle
		    packet_in_nstate <= PACKET_IN_WAIT_WRITE;
		  end
		// else: input_buffer is full. wait...
	      end
	    else
	      // This is an intermmediate packet, and its eth header was already written
	      // Drop current pci2sbu line without writing to input_buffer
	      begin
		write_eth_header = 1'b0;
		pci2sbu_ready <= 1'b1;
		packet_in_nstate <= PACKET_IN_WAIT_WRITE;
	      end
	  end
	
	PACKET_IN_WRITE_HEADER:
	  // Storing message header to input buffer. The header is still valid at pci2sbu_axi4stream_tdata
	  begin
	    // ==============================================================================
	    // ZUC request header format (as agreed with Haggai & Eitan, 28-Apr-2020):
	    // ==============================================================================
	    // pci2sbu[] | Description
	    // ----------+--------------------------------------------------------------------
	    // 511:504     Opcode[7:0]:
	    //             0 – encrypt/decrypt
	    //             1 – authenticate
	    // 503:496     Reserved
	    // 495:480     Message length[15:0] in bytes
	    // 479:416     Message ID (not used by zuc AFU)
	    // 415:288     Key[127:0]
	    // 287:160     IV[127:0]
	    // 159:0       Reserved
	    //
	    //
	    // ==============================================================================
	    // ZUC cipher response header format (as agreed with Haggai & Eitan, 28-Apr-2020):
	    // ==============================================================================
	    // pci2sbu[] | Description
	    // ----------+--------------------------------------------------------------------
	    // 511:504     Opcode (same as in message request)
	    // 503:480     Reserved
	    // 479:416     Message ID (same as in message request)
	    // 415:0       Reserved (cleared in current implementation)
	    //
	    //
	    // ==============================================================================
	    // ZUC auth response header format (as agreed with Haggai & Eitan, 28-Apr-2020):
	    // ==============================================================================
	    // pci2sbu[] | Description
	    // ----------+--------------------------------------------------------------------
	    // 511:504     Opcode (same as in message request)
	    // 503:480     Reserved
	    // 479:416     Message ID (same as in message request)
	    // 415:160     Reserved (cleared in current implementation)
	    // 159:128     MAC
	    // 127:0       Reserved (cleared in current implementation) (tkeep = 128'b0) 
	    //
	    //
	    // ==============================================================================
	    // ZUC Request message tuser (as agreed with Haggai, 6-May-2020):
	    // ==============================================================================
	    // tuser[]   | Field         | Description
	    // ----------+--------------------------------------------------------------------
	    // 71:68       reserved        Unused in zuc AFU
	    // 67:64       afu_id          Haggai: Since we have only one afu, afu_id can be ignored
	    // 63:60       afu_context     Haggai: afu_context should be taken into account, since the endpoint ID is not unique on its own.
	    // 59:56       channel_id      endpoint ID (channel ID per context)
	    // 55:40       Reserved
	    // 39:39       end_of_message  Marks end of message for multi-packet messages.
	    // 38:31       Reserved
	    // 30:30       pkt_type        0 – Ethernet, 1 – RDMA RC
	    // 29:16       Length          Size of the packet.
	    // 15:0        Reserved
	    //
	    //
	    // ==============================================================================
	    // ZUC Response message tuser (as agreed with Haggai, 6-May-2020):
	    // ==============================================================================
	    // tuser[]   | Field         | Description
	    // ----------+--------------------------------------------------------------------
	    // 71:12       Reserved
	    // 11:0        channel_id      = Request.tuser[67:56]
	    //
	    //
	    // ==============================================================================
	    // Internal AFU Message Header:
	    // Generated locally, and transferred between the AFU modules.
	    // Required for proper and/or simplified implementation  	    
	    // ==============================================================================
	    // header[]  | Field         | Description
	    // ----------+--------------------------------------------------------------------
	    // [515:511]   TBD: Add these bits to all intermmediate fifos: {2'b00, EOM, SOM}
	    // [511:160]   pci2sbu_tdata[511:160]
	    // [159:60]    Reserved (cleared)
	    // [59:48]     pci2sbu_axi4stream_tuser[67:56]
	    // [47:40]     Opcode, as captured from "message_opcode" field in message header
	    // [39:24]     Message size (bytes), as captured from "message_size" field in message header
	    // [23:20]     Channel ID
	    // [19:8]      Message ID
	    // [7:0]       Message status:
	    //             [7:3] Reserved
	    //             [2]   Message is too long (> 9KB)
	    //             [1]   Mismatching message length
	    //                   The actual message length (in flits) is compared against the reported length (mesasge_header[495:480])
	    //                   If no match, this message will be dropped (or bypassed) down the road.
	    //             [0]   Message is too long (> 9KB)
	    
	    // Incoming message header is still not stored to input buffer:
	    // Relevant parts of message header are sampled
	    current_in_message_status_update <= 1'b0;
	    current_in_tail_incremented <= 1'b0;

	    if (pci2sbu_axi4stream_vld && ~current_in_buffer_full)
	      begin
		input_buffer_write <= 1;
		input_buffer_meta_write <= 1;
		pci2sbu_ready <= 1;

		if (current_in_som && write_eth_header)
		  // After dropping the Ethernet header, next line is the message header.
		  // Sample message size and opcode:
		  begin
		    current_in_message_size <= pci2sbu_axi4stream_tdata[495:480];
		    current_in_opcode <= pci2sbu_axi4stream_tdata[511:504];
		    write_eth_header = 1'b0;
		  end
		packet_in_nstate <= PACKET_IN_WAIT_WRITE;
	      end
	    else
	      // input_buffer is full. wait here...
	      begin
		input_buffer_write <= 0;
		input_buffer_meta_write <= 0;
		pci2sbu_ready <= 0;
	      end

	  end
	
	PACKET_IN_WAIT_WRITE:
	  begin
	    input_buffer_write <= 0;
	    input_buffer_meta_write <= 0;
	    pci2sbu_ready <= 0;

	    // In an intermmediate Ethernet packet, the header is dropped without being written to input buffer.
	    // Still, even without write, we arive here for the pci2sbu line drop settle.
	    // The following if, prevents tail increment in such a case.
	    if (input_buffer_write)
	      begin
		// Following input_buffer write, increment the *tail pointer
		// The tail pointer is incremented modulo channel_buffer size, to wrap around 9th bit
		current_in_tail <= (current_in_tail & 13'h1e00) | ((current_in_tail + 1) & 13'h01ff);
		current_in_tail_incremented <= 1'b1;
	      end
	    
	    if (pci2sbu_axi4stream_tlast)
	      // last packet of current message has been written to input buffer
	      // som is marked, to indicate end of current message which means; next packet belong to same chid will be a start of new message 
	      // Current channel variables (tail, som, ...)
	      begin
		// Packet has ended. update the channel related variables. If 
		hist_pci2sbu_packet_event <= 1'b1;


		if (current_in_eom)
		  begin
		    // End_Of_Message

		    // Prepare to update & write the message header & status into input_buffer header place_holder
		    current_in_message_status_update <= 1'b1;
		    current_in_message_status_adrs <= current_in_message_start;

		    current_in_som <= 1'b1;
		    
		    // Upon End_Of_Message, update message_id to next successive message
		    // At the end of current packet, the incremented count is saved within current_channel context,
		    // and will be assigned as the message_id of next message 

		    // message_id scheme:
		    // Assumption: Per channel messages are always received in order.
		    // Per channel, the id is incremented upon receiving a new message, and then attached to the message header while being stored to input buffer.
		    // current_in_message_id[11:0]  - message_id. 12bit count. Incremented modulo 12 bit.
		    // Only zuc messages are tagged with a message_id.
		    // Non zuc messages: afubypass, zuc_core bypass, etc.
		    // message_id is incremented only if current message is OK, for proper message ordering at the fifo_out stage.
		    // A message is OK if:
		    // 1. message_id is not masked for current chid (afu_ctrl0[chid] is not set)
		    // 2. It has a valid zuc command
		    // 3. Its length field (header[495:480] matches the actual length
		    // 4. The message length <= 9KB
		    if (current_in_zuccmd && (current_in_message_lines == current_in_flits) && (current_in_flits <= 10'h090))
		      begin
			current_in_message_ok <= 1'b1;
			if (current_in_message_id == 12'hfff)
			  current_in_message_id <= 12'h001; // Lowest ID value is 12'h001, not zero
			else
			  // Testing: Increment by 2 when message_id == 0x10. Done to test the message ordering logic:
			  // Verify that the sbu2pci output is stuck after writing message_id==0x10 
			  //current_in_message_id <= current_in_message_id + 1 + (current_in_chid == 4'h8 && current_in_message_id == 12'h030);
			  current_in_message_id <= current_in_message_id + 1;
		      end
		    
		    // Message status update:
		    if (current_in_illegal_cmd)
		      current_in_message_status[0] <= 1'b1; // Non zuc command encountered

		    if (current_in_message_lines != current_in_flits)
			current_in_message_status[1] <= 1'b1; // 

		    if (current_in_flits > 10'h090)
		      current_in_message_status[2] <= 1'b1; // Message too long (> 9KB)

		    packet_in_nstate <= PACKET_IN_WRITE_STATUS;
		  end

		else
		  begin
		    current_in_som <= 1'b0;
		    update_channel_in_regs <= 1'b1;
		    packet_in_nstate <= PACKET_IN_EOM;
		  end // else: !if(current_in_eom)
		
	      end // if (pci2sbu_axi4stream_tlast)
	    
	    else // if (~pci2sbu_axi4stream_tlast)
	      begin
		// current packet still not ended. Keep writing to input buffer

		if (write_eth_header)
		  begin
		    packet_in_nstate <= PACKET_IN_WRITE_HEADER;
		  end
		else
		  // This is an Ethernet packet, holding an intermmediate piece of the message.
		  // The zuc header already handled in previous packets
		  // Continue with receiving remaining message payload
		  begin
		    packet_in_progress <= 1'b1;
		    packet_in_nstate <= PACKET_IN_PROGRESS;
		  end
	      end
	  end // case: PACKET_IN_WAIT_WRITE
	
	PACKET_IN_PROGRESS:
	  // Reading a complete packet, until tlast
	  // Burst read is supported, depending on pci2sbu_axi4stream_vld and buffer free space avaiability 
	  begin
	    current_in_tail_incremented <= 1'b0;
	    if (~pci2sbu_axi4stream_vld || current_in_buffer_full)
	      // Keep waiting for both valid and non full buffer:
	      begin
		input_buffer_write <= 0;
		input_buffer_meta_write <= 0;
		pci2sbu_ready <= 0;
		packet_in_nstate <= PACKET_IN_PROGRESS;
	      end

	    else
	      begin
		// A line is read from pci2sbu_axi4stream_tdata stream and written to input buffer
		input_buffer_write <= 1;
		input_buffer_meta_write <= 1; // TBD: Recheck this status write. Seems redundant
		pci2sbu_ready <= 1;
		current_in_message_lines <= current_in_message_lines + 1;
		hist_pci2sbu_packet_event_size <= hist_pci2sbu_packet_event_size + 64;       // for pci2sbu_packet_size histogram
		hist_pci2sbu_eompacket_event_size <= hist_pci2sbu_eompacket_event_size + 64; // for pci2sbu_eompacket_size histogram

		// 1-clock write settle
		packet_in_nstate <= PACKET_IN_WAIT_WRITE;
	      end
	  end
	
	PACKET_IN_WRITE_STATUS:
	  begin
	    // current_in_tail already incremented to point to start of next message.
	    current_in_tail_incremented <= 1'b0;
	    current_in_message_lines <= 10'h000;
	    current_in_message_start <= current_in_tail;
	    input_buffer_meta_write <= 1'b1;

	    hist_pci2sbu_packet_event <= 1'b0;
	    hist_pci2sbu_eompacket_event <= 1'b1;
            hist_pci2sbu_message_event_size <= (current_in_message_lines << 6); //Latter message size in bytes 
	    hist_pci2sbu_message_event <= 1'b1;

	    if (~current_in_pkt_type)
	      // Ethernet message ended:
	      // Upon message status update, first message line in input_buffer_data is also overwritten,
	      // with previously sampled header and message related metadata.
	      // Keep notice that while writing the message stats, the head pointer already points to the message start
	      input_buffer_write <= 1'b1; 
	    update_channel_in_regs <= 1'b1;
	    packet_in_nstate <= PACKET_IN_EOM;
	  end

	PACKET_IN_EOM:
	  begin
	    // TBD: Check merging this state with IDLE
	    current_in_tail_incremented <= 1'b0;
	    current_in_message_ok <= 1'b0;
	    current_in_message_status_update <= 1'b0;
	    packet_in_progress <= 1'b0;
	    input_buffer_write <= 0;
	    input_buffer_meta_write <= 0;
	    pci2sbu_ready <= 0;
	    update_channel_in_regs <= 1'b0;
	    hist_pci2sbu_packet_event <= 1'b0;
	    hist_pci2sbu_eompacket_event <= 1'b0;
	    hist_pci2sbu_message_event <= 1'b0;

	    // After end of packet always going to IDLE. Handling a new packet always starts while in IDLE
	    packet_in_nstate <= PACKET_IN_IDLE;

	  end
	
	default:
	  begin
	  end
	
      endcase
    end
  end
  

//=================================================================================================================
// Message read SM: Reading a message from input bufer into the selected ZUC module's fifo_in
//=================================================================================================================
// 1. Prioritize next channel ID to read from: Look at all chidx_valid bits, and round_robin select next valid channel
//    Reminder: chidx_in_message_count > 1 means that chidx has at least one pending message in input buffer
// 2. Look for and round_robin next available ZUC module (any module whose fifox_in has sufficient space to hold the chidx pending message
// 3. Read next message from chidx input_buffer and store to the selected zuc module fifo:
//   3.1. chidx_num_of_lines = chidx_header.message_size/64 // number of 512b lines occupying the message in input buffer
//   3.2. fifox_in <- chidx_header // ZUC module needs it to identify start/end of message, ZUC operation, size, etc.
//   3.3. while (chidx_num_of_lines-- > 0):
//          fifox_in <- input_buffer(chidx_head++)
//   3.4. chidx_in_message_count--;
//   3.5. if (chidx_in_message_count > 0)
//          more complete message(s) are held in chidx input buffer. Read next pending message header:
//          {chidx_header, chidx_valid} = {input_buffer(chidx_head++) , '1};
//   3.6. else
//          No more pending messages. chidx_header should be cleared
//          {chidx_header, chidx_valid} = {'h00000000 , '0};
// 4. Repeat from 1     

  assign messages_validD[15:0] = {input_buffer_watermark_met[15] && (chid_in_message_count[15] > 0),
				  input_buffer_watermark_met[14] && (chid_in_message_count[14] > 0), 
				  input_buffer_watermark_met[13] && (chid_in_message_count[13] > 0),
				  input_buffer_watermark_met[12] && (chid_in_message_count[12] > 0),
				  input_buffer_watermark_met[11] && (chid_in_message_count[11] > 0),
				  input_buffer_watermark_met[10] && (chid_in_message_count[10] > 0),
				  input_buffer_watermark_met[9]  && ( chid_in_message_count[9] > 0),
				  input_buffer_watermark_met[8]  && ( chid_in_message_count[8] > 0),
				  input_buffer_watermark_met[7]  && ( chid_in_message_count[7] > 0),
				  input_buffer_watermark_met[6]  && ( chid_in_message_count[6] > 0),
				  input_buffer_watermark_met[5]  && ( chid_in_message_count[5] > 0),
				  input_buffer_watermark_met[4]  && ( chid_in_message_count[4] > 0),
				  input_buffer_watermark_met[3]  && ( chid_in_message_count[3] > 0),
				  input_buffer_watermark_met[2]  && ( chid_in_message_count[2] > 0),
				  input_buffer_watermark_met[1]  && ( chid_in_message_count[1] > 0),
				  input_buffer_watermark_met[0]  && ( chid_in_message_count[0] > 0)};
  
  // There is at least one full message pending in input buffer, ready to be assigned to ZUC module
  assign message_out_validD = input_buffer_watermark_met[15] && (chid_in_message_count[15] > 0) ||
			      input_buffer_watermark_met[14] && (chid_in_message_count[14] > 0) ||
			      input_buffer_watermark_met[13] && (chid_in_message_count[13] > 0) ||
			      input_buffer_watermark_met[12] && (chid_in_message_count[12] > 0) ||
			      input_buffer_watermark_met[11] && (chid_in_message_count[11] > 0) ||
			      input_buffer_watermark_met[10] && (chid_in_message_count[10] > 0) ||
			      input_buffer_watermark_met[9]  && ( chid_in_message_count[9] > 0) ||
			      input_buffer_watermark_met[8]  && ( chid_in_message_count[8] > 0) ||
			      input_buffer_watermark_met[7]  && ( chid_in_message_count[7] > 0) ||
			      input_buffer_watermark_met[6]  && ( chid_in_message_count[6] > 0) ||
			      input_buffer_watermark_met[5]  && ( chid_in_message_count[5] > 0) ||
			      input_buffer_watermark_met[4]  && ( chid_in_message_count[4] > 0) ||
			      input_buffer_watermark_met[3]  && ( chid_in_message_count[3] > 0) ||
			      input_buffer_watermark_met[2]  && ( chid_in_message_count[2] > 0) ||
			      input_buffer_watermark_met[1]  && ( chid_in_message_count[1] > 0) ||
			      input_buffer_watermark_met[0]  && ( chid_in_message_count[0] > 0);

  assign messages_valid_doubleregD[31:0] = {messages_validD, messages_validD};
  

  // Prioriy encoder: Selecting next chid for message_out
  always @(*) begin
    // Find next roun-robin channel with a valid pending message, starting from latter chid
    if (messages_valid_doubleregD[current_out_chid + 1])
      current_out_chid_delta = 1;
    else if (messages_valid_doubleregD[current_out_chid + 2])
      current_out_chid_delta = 2;
    else if (messages_valid_doubleregD[current_out_chid + 3])
      current_out_chid_delta = 3;
    else if (messages_valid_doubleregD[current_out_chid + 4])
      current_out_chid_delta = 4;
    else if (messages_valid_doubleregD[current_out_chid + 5])
      current_out_chid_delta = 5;
    else if (messages_valid_doubleregD[current_out_chid + 6])
      current_out_chid_delta = 6;
    else if (messages_valid_doubleregD[current_out_chid + 7])
      current_out_chid_delta = 7;
    else if (messages_valid_doubleregD[current_out_chid + 8])
      current_out_chid_delta = 8;
    else if (messages_valid_doubleregD[current_out_chid + 9])
      current_out_chid_delta = 9;
    else if (messages_valid_doubleregD[current_out_chid + 10])
      current_out_chid_delta = 10;
    else if (messages_valid_doubleregD[current_out_chid + 11])
      current_out_chid_delta = 11;
    else if (messages_valid_doubleregD[current_out_chid + 12])
      current_out_chid_delta = 12;
    else if (messages_valid_doubleregD[current_out_chid + 13])
      current_out_chid_delta = 13;
    else if (messages_valid_doubleregD[current_out_chid + 14])
      current_out_chid_delta = 14;
    else if (messages_valid_doubleregD[current_out_chid + 15])
      current_out_chid_delta = 15;
    else
      // We are back to same chid.
      // Keep same chid value
      current_out_chid_delta = 0;

  end // always @ begin

  
  // zuc module selection:
  // 1. Candidate fifo_in should have sufficient space to host the message_size
  // 2. among all fifo_in that comply to rule #1, select the fifo_in with the maximum free space 
  //
  // To simplify num of free entries calculation, the invert fifo_data_out value is assumed which is almost same as num of free entries.
  // For example: 
  // i.e in a 512deep fifo, its data_count output is a 9bit unsigned counter
  // Lets assume its data_count=9'h12c = 300.
  // inverting this value yields ~(9'h12c)=9'h0d3, which is 211
  // 211 designates the number (minus 1) of free entries in the fifo: (512-300) = 212
  // *free_count should be bigger (rather than GE) than *message_lines, to account for the header line as well 
  assign fifo_in_free_regD7 = (fifo7_in_free_count > {5'b0, current_fifo_in_message_lines}) ? 1'b1 : 1'b0;
  assign fifo_in_free_regD6 = (fifo6_in_free_count > {5'b0, current_fifo_in_message_lines}) ? 1'b1 : 1'b0;
  assign fifo_in_free_regD5 = (fifo5_in_free_count > {5'b0, current_fifo_in_message_lines}) ? 1'b1 : 1'b0;
  assign fifo_in_free_regD4 = (fifo4_in_free_count > {5'b0, current_fifo_in_message_lines}) ? 1'b1 : 1'b0;
  assign fifo_in_free_regD3 = (fifo3_in_free_count > {5'b0, current_fifo_in_message_lines}) ? 1'b1 : 1'b0;
  assign fifo_in_free_regD2 = (fifo2_in_free_count > {5'b0, current_fifo_in_message_lines}) ? 1'b1 : 1'b0;
  assign fifo_in_free_regD1 = (fifo1_in_free_count > {5'b0, current_fifo_in_message_lines}) ? 1'b1 : 1'b0;
  assign fifo_in_free_regD0 = (fifo0_in_free_count > {5'b0, current_fifo_in_message_lines}) ? 1'b1 : 1'b0;

  reg [7:0] fifo_in_minload;

  // Module i must be instanciated first, before being enabled :)
  assign zuc_module0_enable = (NUM_MODULES > 0) ? afu_ctrl0[20] : 1'b0;
  assign zuc_module1_enable = (NUM_MODULES > 1) ? afu_ctrl0[21] : 1'b0;
  assign zuc_module2_enable = (NUM_MODULES > 2) ? afu_ctrl0[22] : 1'b0;
  assign zuc_module3_enable = (NUM_MODULES > 3) ? afu_ctrl0[23] : 1'b0;
  assign zuc_module4_enable = (NUM_MODULES > 4) ? afu_ctrl0[24] : 1'b0;
  assign zuc_module5_enable = (NUM_MODULES > 5) ? afu_ctrl0[25] : 1'b0;
  assign zuc_module6_enable = (NUM_MODULES > 6) ? afu_ctrl0[26] : 1'b0;
  assign zuc_module7_enable = (NUM_MODULES > 7) ? afu_ctrl0[27] : 1'b0;


  // ===================================================================
  // zuc modules arbitration
  // ===================================================================  
  // Find next (round_robin) zuc module that complies to these conditions:
  // 1. The zuc_module is enabled
  // 2. There is sufficient fifo_in space to host the selected message_size, 
  // 3. Has the minimum load, among all zuc modules (relevant only in load_based arbitration mode)
  assign fifo_in_free_regD = {zuc_module7_enable && fifo_in_free_regD7 && ((afu_ctrl0[17:16] == 2'b11) ? 1'b1 : fifo_in_minload[7]),
			      zuc_module6_enable && fifo_in_free_regD6 && ((afu_ctrl0[17:16] == 2'b11) ? 1'b1 : fifo_in_minload[6]),
			      zuc_module5_enable && fifo_in_free_regD5 && ((afu_ctrl0[17:16] == 2'b11) ? 1'b1 : fifo_in_minload[5]),
			      zuc_module4_enable && fifo_in_free_regD4 && ((afu_ctrl0[17:16] == 2'b11) ? 1'b1 : fifo_in_minload[4]),
			      zuc_module3_enable && fifo_in_free_regD3 && ((afu_ctrl0[17:16] == 2'b11) ? 1'b1 : fifo_in_minload[3]),
			      zuc_module2_enable && fifo_in_free_regD2 && ((afu_ctrl0[17:16] == 2'b11) ? 1'b1 : fifo_in_minload[2]),
			      zuc_module1_enable && fifo_in_free_regD1 && ((afu_ctrl0[17:16] == 2'b11) ? 1'b1 : fifo_in_minload[1]),
			      zuc_module0_enable && fifo_in_free_regD0 && ((afu_ctrl0[17:16] == 2'b11) ? 1'b1 : fifo_in_minload[0])};
  assign fifo_in_free_doubleregD = ({fifo_in_free_regD[7:0], fifo_in_free_regD[7:0]} >> current_fifo_in_id);
  
  always @(*) begin
    if (fifo_in_free_doubleregD[1])
      fifo_in_id_delta = 1;
    else if (fifo_in_free_doubleregD[2])
      fifo_in_id_delta = 2;
    else if (fifo_in_free_doubleregD[3])
      fifo_in_id_delta = 3;
    else if (fifo_in_free_doubleregD[4])
      fifo_in_id_delta = 4;
    else if (fifo_in_free_doubleregD[5])
      fifo_in_id_delta = 5;
    else if (fifo_in_free_doubleregD[6])
      fifo_in_id_delta = 6;
    else if (fifo_in_free_doubleregD[7])
      fifo_in_id_delta = 7;
    else
      // We are back to same fifo_in_id.
      // Keep same id value
      fifo_in_id_delta = 0;
  end // always @ begin

  // Find the least loaded module. Return its index in fifo_in_minload[]:
  reg [15:0] fifo0_in_load;
  reg [15:0] fifo1_in_load;
  reg [15:0] fifo2_in_load;
  reg [15:0] fifo3_in_load;
  reg [15:0] fifo4_in_load;
  reg [15:0] fifo5_in_load;
  reg [15:0] fifo6_in_load;
  reg [15:0] fifo7_in_load;
  reg [15:0] fifo_in_7to4_lowest_load;
  reg [15:0] fifo_in_3to0_lowest_load;
  
  reg  fifo_in_load_7ge6;
  reg  fifo_in_load_7ge5;
  reg  fifo_in_load_7ge4;
  reg  fifo_in_load_6ge5;
  reg  fifo_in_load_6ge4;
  reg  fifo_in_load_5ge4;
  reg  fifo_in_load_3ge2;
  reg  fifo_in_load_3ge1;
  reg  fifo_in_load_3ge0;
  reg  fifo_in_load_2ge1;
  reg  fifo_in_load_2ge0;
  reg  fifo_in_load_1ge0;
  reg [5:0] fifo_in_3to0_load_compared;
  reg [5:0] fifo_in_7to4_load_compared;
  reg [3:0] fifo_in_3to0_minload; // An asserted bit points to the modulex, whose load is the lowest among load3 thru load0
  reg [3:0] fifo_in_7to4_minload; // An asserted bit points to the modulex, whose load is the lowest among load7 thru load4

  
  always @(*) begin
    // disabled modules load should be ignored (set to to 'infinite' value). 
    fifo0_in_load = zuc_module0_enable
			 ?
			    ((module_fifo_in_watermark_met[0] || fifo_in_full[0])
                            ?
                               ((afu_ctrl0[17:16] == 2'b01)
                                  ?
                                     fifo0_in_total_load
                                  :
                                     {6'b0, fifo_in_data_count[0]})
                            :
                               16'h0000)
			 :
			    16'h7fff;
    
    fifo1_in_load = zuc_module1_enable ? ((module_fifo_in_watermark_met[1] || fifo_in_full[1]) ? ((afu_ctrl0[17:16] == 2'b01) ? fifo1_in_total_load : {6'b0, fifo_in_data_count[1]}) : 16'h0000) : 16'h7fff;
    fifo2_in_load = zuc_module2_enable ? ((module_fifo_in_watermark_met[2] || fifo_in_full[2]) ? ((afu_ctrl0[17:16] == 2'b01) ? fifo2_in_total_load : {6'b0, fifo_in_data_count[2]}) : 16'h0000) : 16'h7fff;
    fifo3_in_load = zuc_module3_enable ? ((module_fifo_in_watermark_met[3] || fifo_in_full[3]) ? ((afu_ctrl0[17:16] == 2'b01) ? fifo3_in_total_load : {6'b0, fifo_in_data_count[3]}) : 16'h0000) : 16'h7fff;
    fifo4_in_load = zuc_module4_enable ? ((module_fifo_in_watermark_met[4] || fifo_in_full[4]) ? ((afu_ctrl0[17:16] == 2'b01) ? fifo4_in_total_load : {6'b0, fifo_in_data_count[4]}) : 16'h0000) : 16'h7fff;
    fifo5_in_load = zuc_module5_enable ? ((module_fifo_in_watermark_met[5] || fifo_in_full[5]) ? ((afu_ctrl0[17:16] == 2'b01) ? fifo5_in_total_load : {6'b0, fifo_in_data_count[5]}) : 16'h0000) : 16'h7fff;
    fifo6_in_load = zuc_module6_enable ? ((module_fifo_in_watermark_met[6] || fifo_in_full[6]) ? ((afu_ctrl0[17:16] == 2'b01) ? fifo6_in_total_load : {6'b0, fifo_in_data_count[6]}) : 16'h0000) : 16'h7fff;
    fifo7_in_load = zuc_module7_enable ? ((module_fifo_in_watermark_met[7] || fifo_in_full[7]) ? ((afu_ctrl0[17:16] == 2'b01) ? fifo7_in_total_load : {6'b0, fifo_in_data_count[7]}) : 16'h0000) : 16'h7fff;

    fifo_in_load_3ge2 = (fifo3_in_load >= fifo2_in_load) ? 1'b1 : 1'b0;
    fifo_in_load_3ge1 = (fifo3_in_load >= fifo1_in_load) ? 1'b1 : 1'b0;
    fifo_in_load_3ge0 = (fifo3_in_load >= fifo0_in_load) ? 1'b1 : 1'b0;
    fifo_in_load_2ge1 = (fifo2_in_load >= fifo1_in_load) ? 1'b1 : 1'b0;
    fifo_in_load_2ge0 = (fifo2_in_load >= fifo0_in_load) ? 1'b1 : 1'b0;
    fifo_in_load_1ge0 = (fifo1_in_load >= fifo0_in_load) ? 1'b1 : 1'b0;

    fifo_in_load_7ge6 = (fifo7_in_load >= fifo6_in_load) ? 1'b1 : 1'b0;
    fifo_in_load_7ge5 = (fifo7_in_load >= fifo5_in_load) ? 1'b1 : 1'b0;
    fifo_in_load_7ge4 = (fifo7_in_load >= fifo4_in_load) ? 1'b1 : 1'b0;
    fifo_in_load_6ge5 = (fifo6_in_load >= fifo5_in_load) ? 1'b1 : 1'b0;
    fifo_in_load_6ge4 = (fifo6_in_load >= fifo4_in_load) ? 1'b1 : 1'b0;
    fifo_in_load_5ge4 = (fifo5_in_load >= fifo4_in_load) ? 1'b1 : 1'b0;

    fifo_in_3to0_load_compared = {fifo_in_load_3ge2, fifo_in_load_3ge1, fifo_in_load_3ge0, fifo_in_load_2ge1, fifo_in_load_2ge0, fifo_in_load_1ge0};
    fifo_in_7to4_load_compared = {fifo_in_load_7ge6, fifo_in_load_7ge5, fifo_in_load_7ge4, fifo_in_load_6ge5, fifo_in_load_6ge4, fifo_in_load_5ge4};

    // Find minimin load among load3 thru load0:
    case (fifo_in_3to0_load_compared)
      // fifo3_in_load is smallest:
      0:
	fifo_in_3to0_minload = 4'b1000;
      4:
	fifo_in_3to0_minload = 4'b1000;
      6:
	fifo_in_3to0_minload = 4'b1000;
      3:
	fifo_in_3to0_minload = 4'b1000;
      7:
	fifo_in_3to0_minload = 4'b1000;

      // fifo2_in_load is smallest:
      56:
	fifo_in_3to0_minload = 4'b0100;
      48:
	fifo_in_3to0_minload = 4'b0100;
      57:
	fifo_in_3to0_minload = 4'b0100;
      41:
	fifo_in_3to0_minload = 4'b0100;
      32:
	fifo_in_3to0_minload = 4'b0100;
      33:
	fifo_in_3to0_minload = 4'b0100;

      // fifo1_in_load is smallest:
      30:
	fifo_in_3to0_minload = 4'b0010;
      62:
	fifo_in_3to0_minload = 4'b0010;
      22:
	fifo_in_3to0_minload = 4'b0010;
      20:
	fifo_in_3to0_minload = 4'b0010;
      60:
	fifo_in_3to0_minload = 4'b0010;
      52:
	fifo_in_3to0_minload = 4'b0010;

      // fifo0_in_load is smallest:
      11:
	fifo_in_3to0_minload = 4'b0001;
      15:
	fifo_in_3to0_minload = 4'b0001;
      43:
	fifo_in_3to0_minload = 4'b0001;
      59:
	fifo_in_3to0_minload = 4'b0001;
      31:
	fifo_in_3to0_minload = 4'b0001;
      63:
	fifo_in_3to0_minload = 4'b0001;
      
      default:
	fifo_in_3to0_minload = 4'b1000; // All counts are in initial order 
    endcase

    // Find minimin load among load7 thru load4:
    case (fifo_in_7to4_load_compared)
      // fifo3_in_load is smallest:
      0:
	fifo_in_7to4_minload = 4'b1000;
      4:
	fifo_in_7to4_minload = 4'b1000;
      6:
	fifo_in_7to4_minload = 4'b1000;
      3:
	fifo_in_7to4_minload = 4'b1000;
      7:
	fifo_in_7to4_minload = 4'b1000;

      // fifo2_in_load is smallest:
      56:
	fifo_in_7to4_minload = 4'b0100;
      48:
	fifo_in_7to4_minload = 4'b0100;
      57:
	fifo_in_7to4_minload = 4'b0100;
      41:
	fifo_in_7to4_minload = 4'b0100;
      32:
	fifo_in_7to4_minload = 4'b0100;
      33:
	fifo_in_7to4_minload = 4'b0100;

      // fifo1_in_load is smallest:
      30:
	fifo_in_7to4_minload = 4'b0010;
      62:
	fifo_in_7to4_minload = 4'b0010;
      22:
	fifo_in_7to4_minload = 4'b0010;
      20:
	fifo_in_7to4_minload = 4'b0010;
      60:
	fifo_in_7to4_minload = 4'b0010;
      52:
	fifo_in_7to4_minload = 4'b0010;

      // fifo0_in_load is smallest:
      11:
	fifo_in_7to4_minload = 4'b0001;
      15:
	fifo_in_7to4_minload = 4'b0001;
      43:
	fifo_in_7to4_minload = 4'b0001;
      59:
	fifo_in_7to4_minload = 4'b0001;
      31:
	fifo_in_7to4_minload = 4'b0001;
      63:
	fifo_in_7to4_minload = 4'b0001;
      
      default:
	fifo_in_7to4_minload = 4'b1000; // All counts are in initial order 
    endcase

    case (fifo_in_7to4_minload)
      4'b1000:
	fifo_in_7to4_lowest_load = fifo7_in_load;
      4'b0100:
	fifo_in_7to4_lowest_load = fifo6_in_load;
      4'b0010:
	fifo_in_7to4_lowest_load = fifo5_in_load;
      4'b0001:
	fifo_in_7to4_lowest_load = fifo4_in_load;

      default:
	fifo_in_7to4_lowest_load = fifo7_in_load;

    endcase

    case (fifo_in_3to0_minload)
      4'b1000:
	fifo_in_3to0_lowest_load = fifo3_in_load;
      4'b0100:
	fifo_in_3to0_lowest_load = fifo2_in_load;
      4'b0010:
	fifo_in_3to0_lowest_load = fifo1_in_load;
      4'b0001:
	fifo_in_3to0_lowest_load = fifo0_in_load;

      default:
	fifo_in_3to0_lowest_load = fifo3_in_load;

    endcase // case (fifo_in_3to0_minload)

    // Find minimin load among load7 thru load0:
    fifo_in_minload = (fifo_in_7to4_lowest_load >= fifo_in_3to0_lowest_load) ?
		      {4'h0, fifo_in_3to0_minload} : // The lowest load is among load3 thru load0
		      {fifo_in_7to4_minload, 4'h0};  // The lowest load is among load7 thru load4
  end

  
  // ===================================================================
  // fifox_in wiring:
  // ===================================================================
  // The selected target fifo for write is done by dedicated fifox_in_valid per fifo 
  // TBD: Replace 64'hffffffffffffffff with count_to_keep(current_fifo_in_message_size[5:0]); 
  assign current_out_keep[63:0] = (current_fifo_in_message_size >= FIFO_LINE_SIZE) ? FULL_LINE_KEEP : 64'hffffffffffffffff;
  assign module_in_data = {input_buffer_rdata[515:48], (current_fifo_in_header || current_fifo_in_eth_header) ? current_fifo_in_message_metadata : input_buffer_rdata[47:0]};
  assign current_out_last = input_buffer_rdata[513];
  assign message_afubypass_data = input_buffer_rdata[515:0];
  assign message_afubypass_last = input_buffer_rdata[513];

  wire force_afubypass, module_in_force_modulebypass, module_in_force_corebypass;
  assign force_afubypass = (afu_ctrl0[19:18] == FORCE_AFU_BYPASS) ? 1'b1 : 1'b0;
  assign module_in_force_modulebypass = (afu_ctrl0[19:18] == FORCE_MODULE_BYPASS) ? 1'b1 : 1'b0;
  assign module_in_force_corebypass = (afu_ctrl0[19:18] == FORCE_ZUC_CORE_BYPASS) ? 1'b1 : 1'b0;

  // =====================================================
  // Message_Out State Machine
  // =====================================================
  // A full message is read from local buffer and written to the selected zuc module
  // A message transfer is triggered if there is at least 1 full message in either of the channels input_queues,
  // and the target zuc module omplies to:
  // 1. The zuc_module is enabled
  // 2. There is sufficient space in its fifo_in to host the selected message size, 
  // 3. Depending on the selected arbitration mode (zuc_ctrl0[17:16]): the zuc module is the least loaded, among all zuc modules
  localparam [3:0]
    CHANNEL_OUT_IDLE        = 4'b0000,
    CHANNEL_OUT_SELECT1     = 4'b0001,
    CHANNEL_OUT_SELECT2     = 4'b0010,
    CHANNEL_OUT_HEADER      = 4'b0011,
    FIFO_IN_SELECT1         = 4'b0100,
    FIFO_IN_SELECT2         = 4'b0101,
    CHANNEL_OUT_PROGRESS    = 4'b0110,
    CHANNEL_AFUBYPASS       = 4'b1000,
    CHANNEL_OUT_DROP        = 4'b1001,
    CHANNEL_OUT_EOM         = 4'b1010;

  always @(posedge clk) begin
    if (reset || afu_reset) begin
      message_out_nstate <= CHANNEL_OUT_IDLE;
      update_channel_out_regs <= 0;
      update_fifo_in_regs <= 0;
      current_out_eom <= 0;
      current_out_som <= 1;  // ???? Is out_som reg needed?
      current_fifo_in_message_size <= 0;
      current_fifo_in_message_words <= 0;
      current_fifo_in_message_lines <= 0;
      current_fifo_in_message_status <= 0;
      current_fifo_in_message_cmd <= MESSAGE_CMD_NOP;
      current_out_chid[3:0] <= 4'b0000;
      current_out_head <= 13'h0000;
      current_out_head_incremented <= 0;
      current_fifo_in_id <= NUM_MODULES - 1; // Default to the last instantiated module, such that next selected module is the successive module (i.e: 0)
      current_fifo_in_header <= 1'b0;
      current_fifo_in_eth_header <= 1'b0;
      fifo_in_readyQ  <= 0;
      module_in_valid  <= 0;
      fifo_in_full[0] <= 0;
      fifo_in_full[1] <= 0;
      fifo_in_full[2] <= 0;
      fifo_in_full[3] <= 0;
      fifo_in_full[4] <= 0;
      fifo_in_full[5] <= 0;
      fifo_in_full[6] <= 0;
      fifo_in_full[7] <= 0;
      message_afubypass_pending <= 1'b0;
      message_afubypass_valid <= 1'b0;
      message_data_valid <= 1'b0;
      input_buffer_rden <= 1'b0; // TBD: Power optimization: Consider enabling input buffer read upon need only
      input_buffer_read_latency <= 3'b000;
      current_fifo_in_message_ok <= 1'b0;
      current_fifo_in_message_type <= 1'b0;
    end

    else begin
      case (message_out_nstate)
	CHANNEL_OUT_IDLE:
	  // channel ID selection is done outside this SM
	  // Prioritize next channel ID to read from: Look at all chidx_valid bits, and round_robin select next valid channel
	  //   Reminder: chidx_in_message_count > 0 means that chidx has at least one pending message in input buffer
	  
	  begin
	    // Sampling the current status of message_out_validD
	    // Keep in mind that messages_validD is continuously updated by the Packet_In SM,
	    // so it is sampled inorder to priority selection of a temporarily prozen value
	    if (message_out_validD)
	      // There is at least 1 valid message in input buffer
	      begin
		input_buffer_rden <= 1'b1;
		message_out_nstate <= CHANNEL_OUT_SELECT1;
	      end
	    else 
	      input_buffer_rden <= 1'b0;
	  end
	
	CHANNEL_OUT_SELECT1:
	  // This state is required to let the message_out channel selection logic to settle
	  begin
	    current_out_chid <= next_out_chid[3:0]; // MOD 16;
	    input_buffer_read_latency <= 3'b000;
	    message_out_nstate <= CHANNEL_OUT_SELECT2;
	  end
	
	CHANNEL_OUT_SELECT2:
	  begin
	    // Sample the selected channel arguments
	    current_out_head <= current_out_headD;
	    
	    // After selecting chid to read a message from, it is time to select the candidate target zuc
	    // We cannot select the target zuc along with the message source, since we need the source message size for the zuc selection,
	    // and that message size is valid only after selecting the message source
	    
	    // zuc module selection: Round_robin around all zuc modules, whose fifo_in has sufficient space to host the selected message_size
	    // The selection is done ouside this SM, with dedicated logic, and sampled at next state.

	    if (input_buffer_read_latency > 0)
	      // input_buffer read latency is 1 clock
	      message_out_nstate <= CHANNEL_OUT_HEADER;
	    else 
	      input_buffer_read_latency <= input_buffer_read_latency + 1;
	    
	  end

	CHANNEL_OUT_HEADER:
	  begin
	    // At this point, the current_out_head pointer is already settled, reading the first message line of the selected chid,
	    // which is the message HEADER.
	    // Extract message size from header. It is required at next state to select a zuc module,
	    // and increment out_head to point to first real line of message

	    current_fifo_in_message_ok <= ~(input_buffer_meta_rdata[0] || input_buffer_meta_rdata[1] || input_buffer_meta_rdata[2]);
	    current_fifo_in_message_type <= input_buffer_rdata[515];
	    current_fifo_in_message_metadata <= input_buffer_meta_rdata[47:0];

	    // Sample message size and cmd, depending on the header type in input_buffer_data[]
	    current_fifo_in_message_size <= input_buffer_meta_rdata[39:24] + input_buffer_rdata[515] ? 'd64 : 'd128; // Adding the header(s) length
	    current_fifo_in_message_words <= {2'b0, input_buffer_meta_rdata[39:26]} + (input_buffer_meta_rdata[25:24] > 0); // Message size in 32b ticks
	    current_fifo_in_message_lines <= input_buffer_meta_rdata[39:30] + (input_buffer_meta_rdata[29:24] > 0); // Message size in 512b ticks
	    // current_out_head is not incremented following the sample of the header,
	    // since the message header should also be transferred to the selected zuc module
	    
	    // Sample the ZUC command from input message, or override to module_bypass if forced
	    current_fifo_in_message_cmd <= module_in_force_modulebypass ? MESSAGE_CMD_MODULEBYPASS : input_buffer_meta_rdata[47:40];
	    
	    // Merge message metadata (id & status) into either of message header and eth header 
	    current_fifo_in_header <= 1'b1;
	    
	    message_out_nstate <= FIFO_IN_SELECT1;
	  end

	FIFO_IN_SELECT1:
	  begin
	    // A message is transferred to a certain fifox_in if there is sufficient space to hold the whole message,
	    // and the message cmd is a valid ZUC command
	    // ???? Potential optimization, to eliminate the waste wait here:
	    //      If there is no free zuc to hold the selected message size, then rather than waiting here,
	    //      return to the message selection state, and select other message source with probably smaller message size
	    if (current_fifo_in_message_ok && ~force_afubypass)
	      begin
		// full[i] indication is updated upon an attempt to write to fifo_in_id == i,
		// while other id's full[] unchanged.
		// TBD: Revisit this 'full' indication scheme:
		//      Unchanging other id's full[] mean that even though other fifo_in might be read (and thus its data_count is depleted),
		//      its full[] indication might not be valid anymore, but it is still not updated, until next write to that fifo_in.
		fifo_in_full[0] <= (current_fifo_in_id == 0) ? ~fifo_in_free_regD0 : fifo_in_full[0];
		fifo_in_full[1] <= (current_fifo_in_id == 1) ? ~fifo_in_free_regD1 : fifo_in_full[1];
		fifo_in_full[2] <= (current_fifo_in_id == 2) ? ~fifo_in_free_regD2 : fifo_in_full[2];
		fifo_in_full[3] <= (current_fifo_in_id == 3) ? ~fifo_in_free_regD3 : fifo_in_full[3];
		fifo_in_full[4] <= (current_fifo_in_id == 4) ? ~fifo_in_free_regD4 : fifo_in_full[4];
		fifo_in_full[5] <= (current_fifo_in_id == 5) ? ~fifo_in_free_regD5 : fifo_in_full[5];
		fifo_in_full[6] <= (current_fifo_in_id == 6) ? ~fifo_in_free_regD6 : fifo_in_full[6];
		fifo_in_full[7] <= (current_fifo_in_id == 7) ? ~fifo_in_free_regD7 : fifo_in_full[7];

		if ((fifo_in_free_regD != 8'h00) &&
	            ((current_fifo_in_message_cmd == MESSAGE_CMD_CONF) || (current_fifo_in_message_cmd == MESSAGE_CMD_INTEG) ||
		     (current_fifo_in_message_cmd == MESSAGE_CMD_MODULEBYPASS)))
		  // There is a fifox_in with sufficient space to hold the current message, and same fifx_in has more free_space than other fifox_in
		  // Current message is a valid message to be loaded to fifox_in
		  // Note: NODULEBYPASS command is handled inside the zuc_module
		  //
		  // TBD: Add remaining prerequisites for delivering a message to ZUC modules: 
		  // AFU_ID, message_size min/max boundaries, ...
		  begin
		    // There is at least one zuc module available to accept the selected message
		    current_fifo_in_id <= next_fifo_in_id[2:0]; // MOD 8
		    message_out_nstate <= FIFO_IN_SELECT2;
		  end
		
		else if  (current_fifo_in_message_cmd == MESSAGE_CMD_AFUBYPASS)
		  // Bypass the whole zuc modules. Transfer the message to sbu2pci 
		  begin
		    // Signal to Output Control that there is a message pending for bypass
		    // message_afubypass_pending indication is kept asserted thru all the bypass process 
		    // At this point, the current_out_head pointer is already settled, reading the first message line of bypassed message
		    message_afubypass_pending <= 1'b1;
		    message_afubypass_valid  <= 1'b1;
		    message_out_nstate <= CHANNEL_AFUBYPASS;
		  end
	      end

	    else
	      // AFU is bypassed when the message not OK, or an AFU bypass has been forced (afu_ctrl0[19:18] == FORCE_AFU_BYPASS)
	      // A message is not OK, if either of:
	      // 1. Unsupported opcode
	      // 2. Message_size (header[495:480]) do not match actual length
	      // 3. Message size > 9KB
	      begin
		message_afubypass_pending <= 1'b1;
		message_afubypass_valid  <= 1'b1;
		message_out_nstate <= CHANNEL_AFUBYPASS;
	      end
	  end
	
	FIFO_IN_SELECT2:
	  begin

	    // Sample the variables related to the selected target zuc module
	    fifo_in_readyQ  <= fifo_in_readyD;

	    // The input_buffer output is already valid with the required read line, once the read address is set
	    // The write to fifo_in 1 -> 4 mux is put here (rather than as random logic outside this block) to avoid potential write glitches
	    module_in_valid     <= 1'b1;
	    message_data_valid <= 1'b1;
	    message_out_nstate <= CHANNEL_OUT_PROGRESS;
	  end

	CHANNEL_OUT_PROGRESS:
	  // At this point both the message source channel and target zuc module have been selected
	  // The input buffer read pointer, current_out_head, still points to the message first line (header)
	  // Read from source channel in input buffer to target zuc module, until end of message
	  begin
	    if (fifo_in_readyQ && message_data_valid)
	      // message_data_valid is a toggle flag, to allow two clocks per read_from_input_buffer_and_write_to_fifx_in.
	      // TBD: revisit the need for the message_data_valid, to reduce the read/write tpt to 1 clock
	      begin
		// Even though it is guaranteed by design that there is sufficient space in target fifo (see fifo free space checkes above),
		// we still verify the target fifo_in is not full, just in case...  

		// Read from chidx_input_buffer and write to target fifo_in.
		// The input_buffer output is already valid with the required read line, once the read address is set
		// The write to fifo_in 1 -> 4 mux is put here (rather than as random logic outside this block) to avoid potential write glitches

		// Once a message read ended, current_out_head pointer should point to start of the next successive message.
		// Increment this pointer to point to next line, following the end of current message,
		// and update the remaining message size
		// The read pointer is incremented modulo channel_buffer size, to wrap around 9th bit
		current_fifo_in_header <= 1'b0;
		if (current_fifo_in_header && ~current_fifo_in_message_type)
		  // If current line is an eth header, attach the message metadata also the subsequent line (message header)
		  current_fifo_in_eth_header <= 1'b1;
		if (current_fifo_in_eth_header)
		  current_fifo_in_eth_header <= 1'b0;
		
		current_out_head <= (current_out_head & 13'h1e00) | ((current_out_head + 1) & 13'h01ff);
		current_out_head_incremented <= 1'b1;
		message_data_valid  <= 1'b0;
		module_in_valid  <= 1'b0;
		
		if (current_out_last)
		  // end of message == EOM indication from input buffer metadata, input_buffer_data[513] 
		  // Using the EOM termination condition rather than *message_count, to avoid lines left over in input_buffer,
		  // in case the *message_size do not match the actual length.
		  begin 
		    update_channel_out_regs <= 1'b1;
		    update_fifo_in_regs <= 1'b1;
		    message_out_nstate <= CHANNEL_OUT_EOM;
		  end
		else
		  begin
		    // Keep reading until end of message
		    current_fifo_in_message_size <= current_fifo_in_message_size - FIFO_LINE_SIZE;

		    // ??? TBD: can we back-to-back read from input buffer, write to fifo_in?
		    // If not, then add here a read/write settle state of 1 clock long
		    // message_out_nstate <= CHANNEL_OUT_READ-WRITE-SETTLE;
		  end
	      end

	    else // !(fifo_in_readyQ)
	      begin
		current_out_head_incremented <= 1'b0;
		module_in_valid  <= 1'b1;
		message_data_valid <= 1'b1;
	      end
	  end
	
	CHANNEL_AFUBYPASS:
	  // Bypass the selected channel to sbu2pci
	  begin
	    // current_out_head already points to next input_buffer line to be bypassed to sbu2pci
	    // No need to check input_buffer valid: Always Valid one clock after incrementing the input_buffer head pointer

	    if (sbu2pci_axi4stream_rdy && message_afubypass_valid && sbu2pci_afubypass_inprogress)
	      begin
		// sbu2pci has read current input_buffer line, prepare reading next line
		current_fifo_in_header <= 1'b0;
		current_out_head <= (current_out_head & 13'h1e00) | ((current_out_head + 1) & 13'h01ff);
		current_out_head_incremented <= 1'b1;
		// wait at least 1 clock, before incrementing head pointer
		message_afubypass_valid  <= 1'b0;

		if (current_out_last)
		  // To end the bypass, we rely on EOM indication rather than on current_fifo_in_message_size,
		  // since the *size parameter extracted from the message header might not match the actual mesasge size.
		  begin 
		    // Bypass end: Clear bypass indication once the message bypass has completed 
		    update_channel_out_regs <= 1'b1;
		    message_out_nstate <= CHANNEL_OUT_EOM;
		  end
		else
		  begin
		    // Keep bypassing until end of message
		    // The read pointer is incremented modulo channel_buffer size, to wrap around 9th bit
		    current_fifo_in_message_size <= current_fifo_in_message_size - FIFO_LINE_SIZE;
		  end
	      end
	    else
	      begin
		message_afubypass_valid <= 1'b1;
		current_out_head_incremented <= 1'b0;
	      end
	  end
	
	CHANNEL_OUT_DROP:
	  // Drop current message from selected channel
	  // Message drop scheme:
	  // A message must be fully contained within input buffer
	  // TBD: Drop optimization: 
	  //      Drop directly from pci2sbu port, rather than copying the whole message into input buffer and then be dropped
	  //      Motivation: Better utilization of input buffer space
	  //      To implement this, the dropping mechanism should:
	  //      1. Idenify the message to be dropped, based on an unsupported message_cmd at the message header valid in pci2sbu 
	  //      2. Track the message tuser.context&ID, while receiving packets from pci2sbu
	  //      3. Since interleaved messages between different channels is allowed: 
	  //      3.1. Drop packets belong to same context&ID, while storing the 'good' packets into its designated queue in input buffer
	  //      3.2. Keep in mind that multiple interleaved messages might need to be dropped at the same time
	  begin
	    // The read pointer is incremented modulo channel_buffer size, to wrap around 9th bit
	    current_fifo_in_header <= 1'b0;
	    current_out_head <= (current_out_head & 13'h1e00) | ((current_out_head + 1) & 13'h01ff);
	    current_out_head_incremented <= 1'b1;
	    
	    //if (current_fifo_in_message_size <= FIFO_LINE_SIZE)
	    // 'end_of_message' == Last 64 bytes (or less) have been read
	    // end_of_message indication takes into accout the exact message size being read, as specified in current_fifo_in_message_size
	    // Anyway, full 512b lines are always read, the message_size alignment
	    if (current_out_last)
	      // To end the drop, we rely on EOM indication rather than on current_fifo_in_message_size,
	      // since the *size parameter extracted from the message header might not match the actual mesasge size.
	      begin 
		update_channel_out_regs <= 1'b1;
		message_out_nstate <= CHANNEL_OUT_EOM;
	      end
	    else
	      begin
		// Keep bypassing until end of message
		current_fifo_in_message_size <= current_fifo_in_message_size - FIFO_LINE_SIZE;
	      end
	  end
	
	CHANNEL_OUT_EOM:
	  begin
	    current_out_head_incremented <= 1'b0;
	    current_fifo_in_header <= 1'b0;
	    module_in_valid  <= 0;
	    message_afubypass_valid  <= 1'b0;
	    message_afubypass_pending <= 1'b0;
	    update_channel_out_regs = 1'b0;
	    update_fifo_in_regs = 1'b0;
	    message_out_nstate <= CHANNEL_OUT_IDLE;
	  end

	default:
	  begin
	  end
	
      endcase
    end // else: !if(reset || afu_reset)
  end
  


  //zuc modules fifox_out to sbu2pci
  //

  localparam [2:0]
    FIFO0_OUT_TO_SBU2PCI = 3'b000,
    FIFO1_OUT_TO_SBU2PCI = 3'b001,
    FIFO2_OUT_TO_SBU2PCI = 3'b010,
    FIFO3_OUT_TO_SBU2PCI = 3'b011,
    FIFO4_OUT_TO_SBU2PCI = 3'b100,
    FIFO5_OUT_TO_SBU2PCI = 3'b101,
    FIFO6_OUT_TO_SBU2PCI = 3'b110,
    FIFO7_OUT_TO_SBU2PCI = 3'b111;

  //zuc module fifo_out arguments selection
  always @(*) begin
    case (current_fifo_out_id)
      FIFO0_OUT_TO_SBU2PCI:
	begin
	  fifo_out_dataD = fifo_out_data[0];
	  fifo_out_lastD = fifo_out_last[0];
	  fifo_out_userD = fifo_out_user[0]; // userD is NOT forwarded to sbu2pci. It is used by sbu2pci SM to identify eth headers !! 
	  fifo_out_statusD = fifo_out_status[0];
	end
      FIFO1_OUT_TO_SBU2PCI:
	begin
	  fifo_out_dataD = fifo_out_data[1];
	  fifo_out_lastD = fifo_out_last[1];
	  fifo_out_userD = fifo_out_user[1];
	  fifo_out_statusD = fifo_out_status[1];
	end
      
      FIFO2_OUT_TO_SBU2PCI:
	begin
	  fifo_out_dataD = fifo_out_data[2];
	  fifo_out_lastD = fifo_out_last[2];
	  fifo_out_userD = fifo_out_user[2];
	  fifo_out_statusD = fifo_out_status[2];
	end
      
      FIFO3_OUT_TO_SBU2PCI:
	begin
	  fifo_out_dataD = fifo_out_data[3];
	  fifo_out_lastD = fifo_out_last[3];
	  fifo_out_userD = fifo_out_user[3];
	  fifo_out_statusD = fifo_out_status[3];
	end

      FIFO4_OUT_TO_SBU2PCI:
	begin
	  fifo_out_dataD = fifo_out_data[4];
	  fifo_out_lastD = fifo_out_last[4];
	  fifo_out_userD = fifo_out_user[4];
	  fifo_out_statusD = fifo_out_status[4];
	end

      FIFO5_OUT_TO_SBU2PCI:
	begin
	  fifo_out_dataD = fifo_out_data[5];
	  fifo_out_lastD = fifo_out_last[5];
	  fifo_out_userD = fifo_out_user[5];
	  fifo_out_statusD = fifo_out_status[5];
	end

      FIFO6_OUT_TO_SBU2PCI:
	begin
	  fifo_out_dataD = fifo_out_data[6];
	  fifo_out_lastD = fifo_out_last[6];
	  fifo_out_userD = fifo_out_user[6];
	  fifo_out_statusD = fifo_out_status[6];
	end

      FIFO7_OUT_TO_SBU2PCI:
	begin
	  fifo_out_dataD = fifo_out_data[7];
	  fifo_out_lastD = fifo_out_last[7];
	  fifo_out_userD = fifo_out_user[7];
	  fifo_out_statusD = fifo_out_status[7];
	end

      default: begin
      end
    endcase
  end

  reg [511:0] sbu2pci_ethernet_header;
  reg 	      sbu2pci_ethernet_header_write;
  reg 	      sbu2pci_next_write_is_message_header;
  reg 	      sbu2pci_imessage_header_write;
  reg 	      sbu2pci_cmessage_header_write;

  
  wire [63:0] zuc_out_keep;
  assign zuc_out_keep = module_in_test_mode && (current_fifo_out_message_size > 0) ? FULL_LINE_KEEP :
			(current_fifo_out_message_size >= FIFO_LINE_SIZE) ? FULL_LINE_KEEP : 
			128'hffffffffffffffff0000000000000000 >> current_fifo_out_message_size[5:0];
  assign sbu2pci_last = sbu2pci_afubypass_inprogress ? message_afubypass_last : fifo_out_lastD;

  // fifox_out & input_buffer_bypass to sbu2pci wiring:
  // tkeep is forced to full line in AFUBYPASS
  assign sbu2pci_axi4stream_tkeep[63:0] = sbu2pci_afubypass_inprogress ? FULL_LINE_KEEP : 
					  ((current_response_cmd == MESSAGE_CMD_INTEG) && sbu2pci_last) ? MAC_RESPONSE_KEEP : zuc_out_keep;

  // sbu2pci_tuser is set to same tuser received on pci2sbu
  assign sbu2pci_axi4stream_tuser[71:0] = {60'b0, sbu2pci_afubypass_inprogress ? 12'b0 : current_response_tuser};

  assign sbu2pci_axi4stream_tdata = sbu2pci_afubypass_inprogress ? message_afubypass_data[511:0] : 

				    // Ethernet header: Swap Eth/IP/UDP addresses
				    sbu2pci_ethernet_header_write ? sbu2pci_ethernet_header : 

				    // Clear reserved part in imessage header:
				    ~module_in_test_mode && ~afu_ctrl2[16] && sbu2pci_imessage_header_write ? {fifo_out_dataD[511:416], 256'b0, fifo_out_dataD[159:128], 128'b0} :

				    // Clear reserved part in cmessage header:
				    ~module_in_test_mode && ~afu_ctrl2[16] && sbu2pci_cmessage_header_write ? {fifo_out_dataD[511:416], 416'b0} :

				    // Next full lines of a message:
				    fifo_out_dataD[511:0];




  
  assign sbu2pci_axi4stream_vld = sbu2pci_afubypass_inprogress ? message_afubypass_valid : sbu2pci_valid;
  assign sbu2pci_axi4stream_tlast = sbu2pci_last;

  // Response message fragmenting:
  // According to Haggai, no need to fragment response messages into 1k packets

  // fif0x_out has a valid message pending if:
  // 1. There is a message pending (message_count > 0)
  // 2. fifo_out_status has a valid output (1 line per each message in fifo_out)
  // 3. The pending message ID for the given chid, is successive to (greater by 1 vs.) previous transferred message for same chid 
  //
  // Notes:
  // 1. fifox_out_message_id is the ID locally generated while assigning the message into the zuc module (added to the message header)
  //    A zero message_id means a non-OK zuc message, for which message ordering is ignored
  // 2. fifox_out_last_message_id is the last written (to sbu2pci) message ID for channel x 
  assign fifo0_out_chid = fifo_out_status[0][7:4];
  assign fifo0_out_message_id = fifo_out_data[0][19:8];
  assign fifo0_out_ignored_message_id = ((((afu_ctrl2[15:0] >> fifo0_out_chid) & 16'h0001) == 16'h0001) || fifo0_out_message_id == 0) ? 1'b0 : 1'b1;

  // Calculating the next expected message_id:
  // Next message_id is incremented, wrapped around 12th bit count
  // Exception: message_id == 0 is avoided, as it is used to tag non zuc-OK messages
  assign fifo0_out_expected_message_id = (fifo0_out_last_message_id[11:0] == 12'hfff) ? 12'h001 : fifo0_out_last_message_id[11:0] + 1;

  // fifox_last_message_id[] holds the message_id of the last message written to sbu2pci from channel x
  // Notice that the id itself is only 12 bits, while bit 15 is used for last_message_id_valid tagging.
  // The valid tagging is aimed to avoid comparing fifox_out_message_id to a non initialized fifox_out_last_message_id, as happens after reset.
  // The valid bit will be asserted upon first message stored to sbu2pci.
  // message_id == 0 is reserved for tagging non-zucOK messages (bypassed messages, illegal zuc commands, non matching length, length > 9KB) 
  assign fifo0_out_message_id_ok = (fifo0_out_last_message_id[15]) ? (fifo0_out_message_id == fifo0_out_expected_message_id) : 1'b1;
  assign fifo0_out_message_valid = (fifo0_out_message_count > 0) && fifo_out_status_valid[0] && (fifo0_out_message_id_ok || ~fifo0_out_ignored_message_id); 

  assign fifo1_out_chid = fifo_out_status[1][7:4];
  assign fifo1_out_message_id = fifo_out_data[1][19:8];
  assign fifo1_out_ignored_message_id = ((((afu_ctrl2[15:0] >> fifo1_out_chid) & 16'h0001) == 16'h0001) || fifo1_out_message_id == 0) ? 1'b0 : 1'b1;
  assign fifo1_out_expected_message_id = (fifo1_out_last_message_id[11:0] == 12'hfff) ? 12'h001 : fifo1_out_last_message_id[11:0] + 1;
  assign fifo1_out_message_id_ok = (fifo1_out_last_message_id[15]) ? (fifo1_out_message_id == fifo1_out_expected_message_id) : 1'b1;
  assign fifo1_out_message_valid = (fifo1_out_message_count > 0) && fifo_out_status_valid[1] && (fifo1_out_message_id_ok || ~fifo1_out_ignored_message_id);

  assign fifo2_out_chid = fifo_out_status[2][7:4];
  assign fifo2_out_message_id = fifo_out_data[2][19:8];
  assign fifo2_out_ignored_message_id = ((((afu_ctrl2[15:0] >> fifo2_out_chid) & 16'h0001) == 16'h0001) || fifo2_out_message_id == 0) ? 1'b0 : 1'b1;
  assign fifo2_out_expected_message_id = (fifo2_out_last_message_id[11:0] == 12'hfff) ? 12'h001 : fifo2_out_last_message_id[11:0] + 1;
  assign fifo2_out_message_id_ok = (fifo2_out_last_message_id[15]) ? (fifo2_out_message_id == fifo2_out_expected_message_id) : 1'b1;
  assign fifo2_out_message_valid = (fifo2_out_message_count > 0) && fifo_out_status_valid[2] && (fifo2_out_message_id_ok || ~fifo2_out_ignored_message_id);

  assign fifo3_out_chid = fifo_out_status[3][7:4];
  assign fifo3_out_message_id = fifo_out_data[3][19:8];
  assign fifo3_out_ignored_message_id = ((((afu_ctrl2[15:0] >> fifo3_out_chid) & 16'h0001) == 16'h0001) || fifo3_out_message_id == 0) ? 1'b0 : 1'b1;
  assign fifo3_out_expected_message_id = (fifo3_out_last_message_id[11:0] == 12'hfff) ? 12'h001 : fifo3_out_last_message_id[11:0] + 1;
  assign fifo3_out_message_id_ok = (fifo3_out_last_message_id[15]) ? (fifo3_out_message_id == fifo3_out_expected_message_id) : 1'b1;
  assign fifo3_out_message_valid = (fifo3_out_message_count > 0) && fifo_out_status_valid[3] && (fifo3_out_message_id_ok || ~fifo3_out_ignored_message_id);

  assign fifo4_out_chid = fifo_out_status[4][7:4];
  assign fifo4_out_message_id = fifo_out_data[4][19:8];
  assign fifo4_out_ignored_message_id = ((((afu_ctrl2[15:0] >> fifo4_out_chid) & 16'h0001) == 16'h0001) || fifo4_out_message_id == 0) ? 1'b0 : 1'b1;
  assign fifo4_out_expected_message_id = (fifo4_out_last_message_id[11:0] == 12'hfff) ? 12'h001 : fifo4_out_last_message_id[11:0] + 1;
  assign fifo4_out_message_id_ok = (fifo4_out_last_message_id[15]) ? (fifo4_out_message_id == fifo4_out_expected_message_id) : 1'b1;
  assign fifo4_out_message_valid = (fifo4_out_message_count > 0) && fifo_out_status_valid[4] && (fifo4_out_message_id_ok || ~fifo4_out_ignored_message_id);

  assign fifo5_out_chid = fifo_out_status[5][7:4];
  assign fifo5_out_message_id = fifo_out_data[5][19:8];
  assign fifo5_out_ignored_message_id = ((((afu_ctrl2[15:0] >> fifo5_out_chid) & 16'h0001) == 16'h0001) || fifo5_out_message_id == 0) ? 1'b0 : 1'b1;
  assign fifo5_out_expected_message_id = (fifo5_out_last_message_id[11:0] == 12'hfff) ? 12'h001 : fifo5_out_last_message_id[11:0] + 1;
  assign fifo5_out_message_id_ok = (fifo5_out_last_message_id[15]) ? (fifo5_out_message_id == fifo5_out_expected_message_id) : 1'b1;
  assign fifo5_out_message_valid = (fifo5_out_message_count > 0) && fifo_out_status_valid[5] && (fifo5_out_message_id_ok || ~fifo5_out_ignored_message_id);

  assign fifo6_out_chid = fifo_out_status[6][7:4];
  assign fifo6_out_message_id = fifo_out_data[6][19:8];
  assign fifo6_out_ignored_message_id = ((((afu_ctrl2[15:0] >> fifo6_out_chid) & 16'h0001) == 16'h0001) || fifo6_out_message_id == 0) ? 1'b0 : 1'b1;
  assign fifo6_out_expected_message_id = (fifo6_out_last_message_id[11:0] == 12'hfff) ? 12'h001 : fifo6_out_last_message_id[11:0] + 1;
  assign fifo6_out_message_id_ok = (fifo6_out_last_message_id[15]) ? (fifo6_out_message_id == fifo6_out_expected_message_id) : 1'b1;
  assign fifo6_out_message_valid = (fifo6_out_message_count > 0) && fifo_out_status_valid[6] && (fifo6_out_message_id_ok || ~fifo6_out_ignored_message_id);

  assign fifo7_out_chid = fifo_out_status[7][7:4];
  assign fifo7_out_message_id = fifo_out_data[7][19:8];
  assign fifo7_out_ignored_message_id = ((((afu_ctrl2[15:0] >> fifo7_out_chid) & 16'h0001) == 16'h0001) || fifo7_out_message_id == 0) ? 1'b0 : 1'b1;
  assign fifo7_out_expected_message_id = (fifo7_out_last_message_id[11:0] == 12'hfff) ? 12'h001 : fifo7_out_last_message_id[11:0] + 1;
  assign fifo7_out_message_id_ok = (fifo7_out_last_message_id[15]) ? (fifo7_out_message_id == fifo7_out_expected_message_id) : 1'b1;
  assign fifo7_out_message_valid = (fifo7_out_message_count > 0) && fifo_out_status_valid[7] && (fifo7_out_message_id_ok || ~fifo7_out_ignored_message_id);

  // There is at least one valid message pending in either of fifox_out, ready to be transferred to sbu2pci
  assign fifo_out_message_validD = fifo7_out_message_valid || fifo6_out_message_valid || fifo5_out_message_valid || fifo4_out_message_valid ||
				   fifo3_out_message_valid || fifo2_out_message_valid || fifo1_out_message_valid || fifo0_out_message_valid;
  assign fifo_out_message_valid_regD[7:0] = {fifo7_out_message_valid, fifo6_out_message_valid, fifo5_out_message_valid, fifo4_out_message_valid,
					     fifo3_out_message_valid, fifo2_out_message_valid, fifo1_out_message_valid, fifo0_out_message_valid};
  assign fifo_out_message_valid_doubleregD = {fifo_out_message_valid_regD, fifo_out_message_valid_regD};
  
  always @(*) begin
    // Find next roun-robin zuc unit with at least one full message, starting from latter fifo_in_id
    if (fifo_out_message_valid_doubleregD[current_fifo_out_id+1])
      fifo_out_id_delta = 1;
    else if (fifo_out_message_valid_doubleregD[current_fifo_out_id+2])
      fifo_out_id_delta = 2;
    else if (fifo_out_message_valid_doubleregD[current_fifo_out_id+3])
      fifo_out_id_delta = 3;
    else if (fifo_out_message_valid_doubleregD[current_fifo_out_id+4])
      fifo_out_id_delta = 4;
    else if (fifo_out_message_valid_doubleregD[current_fifo_out_id+5])
      fifo_out_id_delta = 5;
    else if (fifo_out_message_valid_doubleregD[current_fifo_out_id+6])
      fifo_out_id_delta = 6;
    else if (fifo_out_message_valid_doubleregD[current_fifo_out_id+7])
      fifo_out_id_delta = 7;
    else
      // We are back to same fifo_in_id.
      // Keep same id value
      fifo_out_id_delta = 0;
  end // always @ begin


  // Messages ordering:
  // ================
  // Per each channel, keep track of last message ID which has been transferred to sbu2pci
  //    chidx_last_message_id[9:0], x E {0..15}.
  // If there is a message pending (fifox_out_message_count > 0)
  //    then this info is avaiable:
  //    1. fifox_out_data[15:12] - channel_id[3:0]
  //    2. fifox_out[11:2]       - message_id[9:0]
  //
  // For messages ordering, for the above channel_id[], verify that 
  //    last_message_id[] = lookup(chidx_last_message_id[], channel_id[]) // Return channel_id[] reg of channel x 
  //    if (message_id[] == last_message_id[] + 1)
  //       then fifox_out pending message is valid for transfer to sbu2pci !!
  //    round_robin select among all valid fifox_out     
  //    upon end of transfer:
  //       update chidx_last_message_id[] = message_id[]


  //=================================================================================================================
  // fifox_out to sbu2pci State Machine: Message read from selected zuc output to sbu2pci port
  //=================================================================================================================
  // A zuc output fifo is candidate for being selected only if hosts at least one full message.
  localparam [2:0]
    SBU2PCI_OUT_IDLE        = 3'b000,
    SBU2PCI_OUT_SELECT1     = 3'b001,
    SBU2PCI_OUT_SELECT2     = 3'b010,
    SBU2PCI_OUT_HEADER      = 3'b011,
    SBU2PCI_OUT_NEXT_FLIT   = 3'b100,
    SBU2PCI_OUT_WAIT_READY  = 3'b101,
    SBU2PCI_AFUBYPASS       = 3'b110,
    SBU2PCI_OUT_EOM         = 3'b111;

  always @(posedge clk) begin
    if (reset || afu_reset) begin
      sbu2pci_out_nstate <= SBU2PCI_OUT_IDLE;
      current_fifo_out_id <= 4'h0;
      current_fifo_out_message_size <= 16'b0;
      // current_fifo_out_message_size_progress <= 0; // Used for large message fragmentation into smaller packets
      module_out_ready <= 1'b0;
      module_out_status_ready <= 1'b0;
      sbu2pci_afubypass_inprogress <= 1'b0;
      sbu2pci_ethernet_header_write <= 1'b0;
      sbu2pci_imessage_header_write <= 1'b0;
      sbu2pci_cmessage_header_write <= 1'b0;
      sbu2pci_next_write_is_message_header <= 1'b0;
      sbu2pci_valid <= 1'b0;
      update_fifo_out_regs = 1'b0;
      current_fifo_out_chid <= 4'h0;
      total_sbu2pci_out_message_count <= 36'b0;
      total_afubypass_message_count <= 36'b0;
      hist_sbu2pci_response_event <= 1'b0;
      hist_sbu2pci_response_event_size <= 16'h0000;
    end

    else begin
      case (sbu2pci_out_nstate)
	SBU2PCI_OUT_IDLE:
	  begin
	    if (fifo_out_message_validD || message_afubypass_pending)
	      // There is at least 1 valid message in zuc output fifos,
	      // or a message in input_buffer with CMD == 3 (full message bypass)
	      begin
		if (message_afubypass_pending)
		  begin
		    // At this point, message_afubypass_data already valid with first line (header) valid.
		    // Extract the message size 
		    current_fifo_out_message_size <= message_afubypass_data[39:24] + message_afubypass_data[515] ? 'd64 : 'd128; // Adding the message/eth headers length
		    sbu2pci_afubypass_inprogress <= 1'b1;
		    sbu2pci_out_nstate <= SBU2PCI_AFUBYPASS;
		  end

		else
		  begin		
		    sbu2pci_out_nstate <= SBU2PCI_OUT_SELECT1;
		  end
	      end
	  end

	SBU2PCI_OUT_SELECT1:
	  begin
	    // TBD: If timing allows, merge this state with IDLE
	    current_fifo_out_id <= next_fifo_out_id;
	    sbu2pci_out_nstate <= SBU2PCI_OUT_SELECT2;
	  end
	
	SBU2PCI_OUT_SELECT2:
	  begin
	    // When modules bypass is forced, the actual response command, is overridden
	    current_response_cmd <= module_in_force_modulebypass ? MESSAGE_CMD_MODULEBYPASS : fifo_out_dataD[47:40];
	    current_out_zuccmd <= (fifo_out_dataD[47:40] == MESSAGE_CMD_CONF) || (fifo_out_dataD[47:40] == MESSAGE_CMD_INTEG);

	    current_fifo_out_message_type <= fifo_out_userD;
	    current_response_tuser <= fifo_out_dataD[59:48];

	    // Adding the message/eth headers and module_test_mode flits length to the response message_size
	    current_fifo_out_message_size <= ((fifo_out_dataD[47:40] == MESSAGE_CMD_INTEG) ? 
					      16'h0040 :                                   // Integ response length is a single flit
					      fifo_out_dataD[39:24] + 16'h0040) +          // CONF response length
					     (fifo_out_userD ? 16'h0000 : 16'h0040 ) +     // Ethernet header length
					     (module_in_test_mode ? 16'h0100 : 16'h0000 ); // Module test_mode extra flits

					     
	    // Ethernet header: Calculating ip & udp leangths:
	    // ===============================================
	    // INTEG - 2 512b lines: First line is the eth header. Length is 64 - 14 (ETh header) = 50 bytes
            //                       Second line is the MAC response, whose length is fixed at 48 bytes.
	    //                       ip header length: 50+48 = 98 = 'h62.
	    // CONF - Multiple 512b lines: first line length is the eth header. Length is 64 - 14 (ETh header) = 50 bytes
            //                       Second line is the message response header: 64 bytes
            //                       Remaining lines length is the same as the original message length
	    //                       ip header length: 50+64+message_length = 'h72 + message_length
	    // module_test_mode:      4 full lines are added: 64B x 4 = 256 = 'h100
	    ip_header_length <= ((fifo_out_dataD[47:40] == MESSAGE_CMD_INTEG) ? 16'h0062 : (fifo_out_dataD[39:24] + 16'h0072)) +
				(module_in_test_mode ? 16'h0100 : 16'h0000);

	    // INTEG - 2 512b lines: First line is the eth header. Length is 64 - 34 (eth & ip headers) = 30 bytes
            //                       Second line is the MAC response, whose length is fixed at 48 bytes.
	    //                       udp header length: 30+48 = 78 = 'h4e.
	    // CONF - Multiple 512b lines: first line length is 64 - 34 (eth & ip headers) = 30 bytes
            //                       Second line is the message response header: 64 bytes
            //                       Remaining lines length is the same as the original message length
	    //                       udp header length: 30+64+message_length = 'h5e + message_length

	    // module_test_mode:      4 full lines are added: 64B x 4 = 256 = 'h100
	    udp_header_length <= ((fifo_out_dataD[47:40] == MESSAGE_CMD_INTEG) ? 16'h004e : (fifo_out_dataD[39:24] + 16'h005e)) +
				 (module_in_test_mode ? 16'h0100 : 16'h0000);

	    current_fifo_out_message_id <= fifo_out_dataD[19:8];
	    current_fifo_out_chid <= fifo_out_statusD[7:4];   // TBD: Drop status line from fifox_out_status fifo after reading...
	    current_fifo_out_status <= fifo_out_statusD[3:0]; // TBD: Add this to sbu2pci_axi4stream_tdata header line
	    sbu2pci_out_nstate <= SBU2PCI_OUT_HEADER;
	  end
	
	SBU2PCI_OUT_HEADER:
	  begin
	    // First line of a message in fifox_out is always a 512b header
	    // This line is read and updated, before being written to sbu2pci
	    //
	    // Extract message size from header, then read (drop) first line from the selected fifo
	    // In CMD_INTEG, the out message_size is fixed to full 512b line.
	    // In CMD_CONF, the output message_size is the original message size (no need to add the header length since the header is being written in current state)
	    // Notice that fifox_out_valid is not checked, since this transfer is initiated only if the selected fifo hosts at least one full message

	    // sbu2pci_message_size histogram: Set the sbu2pci_message_size event arguments
	    // Sample the respone payload size, : If INTEG response then set size = 0, otherwise deduct the header length.
	    hist_sbu2pci_response_event_size <= (current_response_cmd == MESSAGE_CMD_INTEG) ? 0 : current_fifo_out_message_size - 64; 
	    hist_sbu2pci_response_event_chid <= current_fifo_out_chid;

	    // Sample the Ethernet header



	    if (~current_fifo_out_message_type)
	      begin
		sbu2pci_ethernet_header_write <= 1'b1;
		sbu2pci_ethernet_header <= {fifo_out_dataD[`ETH_SRC], fifo_out_dataD[`ETH_DST], // Swapped eth src/dst
					    fifo_out_dataD[`ETH_TYPE],                          // unchanged
					    fifo_out_dataD[`IP_VERSION],                        // unchaned
					    ip_header_length,    		                // Updated ip length
					    fifo_out_dataD[`IP_FLAGS],                          // unchaned
					    16'h0000,                                           // Cleared ip chekcksum (not calculated)
					    fifo_out_dataD[`IP_SRC], fifo_out_dataD[`IP_DST],   // Swapped ip src/dst
					    fifo_out_dataD[`UDP_SRC], fifo_out_dataD[`UDP_DST], // Swapped udp src/dst
					    udp_header_length,					// Updated udp length
					    16'h0000,                                           // Cleared udp chekcksum (not calculated)
					    fifo_out_dataD[`HEADER_TAIL],                       // unchaned header part
		                            afu_ctrl2[16] ? fifo_out_dataD[`HEADER_METADATA] : 60'b0}; // Optional header metadata
	      end


	    if (sbu2pci_axi4stream_rdy)
	      // Wait here as long as sbu2pci did not capture this line
	      begin
		sbu2pci_valid <= 1'b1;
		module_out_ready  <= 1'b1;
		module_out_status_ready <= 1'b1;

		// A flit is being written. Lets verify what flit it is:
		if (current_fifo_out_message_type) // RDMA RC response
		  begin
		    if (current_response_cmd == MESSAGE_CMD_INTEG)
		      begin
			if (~module_in_test_mode)
			  // Non Module test mode: Writing a single flit RDMA RC Integrity response
			  begin
			    sbu2pci_imessage_header_write <= 1'b1;
			    update_fifo_out_regs = 1'b1;
			    total_sbu2pci_out_message_count <= total_sbu2pci_out_message_count + 1;
			    hist_sbu2pci_response_event <= 1'b1;
			    sbu2pci_out_nstate <= SBU2PCI_OUT_EOM;
			  end
			else
			  // Module test mode: RDMA RC Integrity response includes muliple flits
			  begin
			    sbu2pci_out_nstate <= SBU2PCI_OUT_NEXT_FLIT;
			  end
		      end
		    
		    else if (current_response_cmd == MESSAGE_CMD_CONF)
		      begin
			// Confidentiality message response
			sbu2pci_cmessage_header_write <= 1'b1;
			sbu2pci_out_nstate <= SBU2PCI_OUT_NEXT_FLIT;
		      end
		    else
		      begin
			// ModuleBypass response
			sbu2pci_out_nstate <= SBU2PCI_OUT_NEXT_FLIT;
		      end

		  end // if (current_fifo_out_message_type)
		else
		  // Written flit: Ethernet response header
		  // Next flit write is the header of either Confidentiality or Integrity response
		  begin
		    sbu2pci_next_write_is_message_header <= 1'b1;
		    sbu2pci_out_nstate <= SBU2PCI_OUT_NEXT_FLIT;
		  end
	      end
	  end

	SBU2PCI_OUT_NEXT_FLIT:
	  begin
	    sbu2pci_ethernet_header_write <= 1'b0;
	    sbu2pci_imessage_header_write <= 1'b0;
	    sbu2pci_cmessage_header_write <= 1'b0;
	    sbu2pci_valid <= 1'b0;
	    module_out_ready  <= 1'b0;
	    module_out_status_ready <= 1'b0;

	    if (sbu2pci_last)
	      // To terminate, we rely on EOM indication, rather than on *message_size, since the *size might not match the actual message size.
	      begin
		module_out_ready  <= 1'b0;
		update_fifo_out_regs = 1'b1;
		total_sbu2pci_out_message_count <= total_sbu2pci_out_message_count + 1;
		hist_sbu2pci_response_event <= 1'b1;
		sbu2pci_out_nstate <= SBU2PCI_OUT_EOM;
	      end
	    else
	      begin
		current_fifo_out_message_size <= current_fifo_out_message_size - FIFO_LINE_SIZE;
		sbu2pci_out_nstate <= SBU2PCI_OUT_WAIT_READY;
	      end
	  end
	
	SBU2PCI_OUT_WAIT_READY:
	  begin
	    if (sbu2pci_next_write_is_message_header)
	      begin
		sbu2pci_next_write_is_message_header <= 1'b0;
		if (current_response_cmd == MESSAGE_CMD_INTEG)
		  sbu2pci_imessage_header_write <= 1'b1;
		else if (current_response_cmd == MESSAGE_CMD_CONF)
		  sbu2pci_cmessage_header_write <= 1'b1;
		else
		  begin
		    // Module bypass command
		    sbu2pci_imessage_header_write <= 1'b0;
		    sbu2pci_cmessage_header_write <= 1'b0;
		  end
	      end

	    if (sbu2pci_axi4stream_rdy)
	      begin
		// Read from the selected fifox_out and write to sbu2pci, as long as sbu2pci is ready
		// No need to check fifox_out_valid, since we already selected a fifox_out which has at least one full message
		//
		// The read from fifox_out is put here (rather than as random logic outside this block) to avoid potential read glitches
		module_out_ready  <= 1'b1;

		// According to Haggai, no need to fragment response message:
		// if (current_fifo_out_message_size_progress >= MAX_PACKET_SIZE)
		// Message fragmetation to 1K packets.
		// sbu2pci_axi4stream_tlast will be asserted once this size crosses the predefined max_packet size
		// From this state machine point of view, the whole message is transferred as one piece of data.
		// This SM does not care that tlast is asserted at 1K boundaries.
		// Once tlast has been asserted, the uccessive fragment (packet) will immediately follow the one just being marked with tlast
		// tlast is asynchronously generated, outside  block.
		//
		// Keep reading till end of message
		sbu2pci_valid <= 1'b1;
		sbu2pci_out_nstate <= SBU2PCI_OUT_NEXT_FLIT;
	      end // if (sbu2pci_axi4stream_rdy)
	    
	    else
	      begin
		// sbu2pci not ready, wait...
		sbu2pci_valid <= 1'b0;
		module_out_ready  <= 1'b0;
	      end
	  end

	SBU2PCI_AFUBYPASS:
	  // ZUC modules bypass: Transfer Inpur Steer buffer output directly to pci2sbu output.
	  // First line of a message is always a 512b header
	  // unlike in normal mode, the header flit IS transferred to sbu2pci !!!
	  begin
	    if (sbu2pci_axi4stream_rdy & message_afubypass_valid)
	      begin
		// sbu2pci data, keep, last are handled by external logic 		
		if (message_afubypass_last)
		  // To end the bypass, we rely on EOM indication rather than on *message_size, since the *size might not match the actual size
		  begin
		    total_afubypass_message_count <= total_afubypass_message_count + 1;
		    sbu2pci_out_nstate <= SBU2PCI_OUT_EOM;
		  end
		else
		  // Keep reading till end of message
		  current_fifo_out_message_size <= current_fifo_out_message_size - FIFO_LINE_SIZE;
	      end
	  end
	
	SBU2PCI_OUT_EOM:
	  begin
	    hist_sbu2pci_response_event <= 1'b0;
	    module_out_ready  <= 1'b0;
	    module_out_status_ready <= 1'b0;
	    sbu2pci_ethernet_header_write <= 1'b0;
	    sbu2pci_next_write_is_message_header <= 1'b0;
	    sbu2pci_imessage_header_write <= 1'b0;
	    sbu2pci_cmessage_header_write <= 1'b0;
	    sbu2pci_valid <= 1'b0;
	    sbu2pci_afubypass_inprogress <= 1'b0;
	    update_fifo_out_regs = 1'b0;
	    sbu2pci_out_nstate <= SBU2PCI_OUT_IDLE;
	  end

  	default: begin
	end
      endcase

    end // else: !if(reset || afu_reset)
  end // always @ (posedge clk)
  


//fifo_out to sbu2pci arguments update
  always @(posedge clk) begin
    if (reset || afu_reset) begin
      // fifo_out message_count is a common register to both zuc write to fifox_out & read to sbu2pci operations.
      // Both write&read/to&from fifox_out state machines affect this count register.
      // Unsigned count, max 256 messages/channel: 512 (=8K/16) entries/channel, minimum 1024b (two fifo lines)/message
      fifo0_out_message_count[8:0] <= 0;
      fifo1_out_message_count[8:0] <= 0;
      fifo2_out_message_count[8:0] <= 0;
      fifo3_out_message_count[8:0] <= 0;
      fifo4_out_message_count[8:0] <= 0;
      fifo5_out_message_count[8:0] <= 0;
      fifo6_out_message_count[8:0] <= 0;
      fifo7_out_message_count[8:0] <= 0;

      total_fifo0_out_message_count <= 32'b0;
      total_fifo1_out_message_count <= 32'b0;
      total_fifo2_out_message_count <= 32'b0;
      total_fifo3_out_message_count <= 32'b0;
      total_fifo4_out_message_count <= 32'b0;
      total_fifo5_out_message_count <= 32'b0;
      total_fifo6_out_message_count <= 32'b0;
      total_fifo7_out_message_count <= 32'b0;
      total_zuc_out_message_count <= 36'b0;

      // Recording last valid (valid == ordered) message ID read from either of fifox_out, to be written to sbu2pci
      // MSbit is the id valid indication
      chid0_last_message_id[15:0] <= 16'h8000;
      chid1_last_message_id[15:0] <= 16'h8000;
      chid2_last_message_id[15:0] <= 16'h8000;
      chid3_last_message_id[15:0] <= 16'h8000;
      chid4_last_message_id[15:0] <= 16'h8000;
      chid5_last_message_id[15:0] <= 16'h8000;
      chid6_last_message_id[15:0] <= 16'h8000;
      chid7_last_message_id[15:0] <= 16'h8000;
      chid8_last_message_id[15:0] <= 16'h8000;
      chid9_last_message_id[15:0] <= 16'h8000;
      chid10_last_message_id[15:0] <= 16'h8000;
      chid11_last_message_id[15:0] <= 16'h8000;
      chid12_last_message_id[15:0] <= 16'h8000;
      chid13_last_message_id[15:0] <= 16'h8000;
      chid14_last_message_id[15:0] <= 16'h8000;
      chid15_last_message_id[15:0] <= 16'h8000;
    end
    
    else begin
      // Statistics mesasge counts
      total_fifo0_out_message_count <= update_zuc_module_regs[0] ? total_fifo0_out_message_count + 1 : total_fifo0_out_message_count;
      total_fifo1_out_message_count <= update_zuc_module_regs[1] ? total_fifo1_out_message_count + 1 : total_fifo1_out_message_count;
      total_fifo2_out_message_count <= update_zuc_module_regs[2] ? total_fifo2_out_message_count + 1 : total_fifo2_out_message_count;
      total_fifo3_out_message_count <= update_zuc_module_regs[3] ? total_fifo3_out_message_count + 1 : total_fifo3_out_message_count;
      total_fifo4_out_message_count <= update_zuc_module_regs[4] ? total_fifo4_out_message_count + 1 : total_fifo4_out_message_count;
      total_fifo5_out_message_count <= update_zuc_module_regs[5] ? total_fifo5_out_message_count + 1 : total_fifo5_out_message_count;
      total_fifo6_out_message_count <= update_zuc_module_regs[6] ? total_fifo6_out_message_count + 1 : total_fifo6_out_message_count;
      total_fifo7_out_message_count <= update_zuc_module_regs[7] ? total_fifo7_out_message_count + 1 : total_fifo7_out_message_count;
      
      // Total out_mesage count: incremented per each of the asserted bits in update_zuc_module_regs[].
      // Notice that more than one asserted bit in update_zuc_module_regs[] at a time is possible !!!!  
      // Implementation note:
      // The following is an adder of 8 single-bit operands. Replace this with csa tree, if timing-wise needed.
      total_zuc_out_message_count <= total_zuc_out_message_count +
				      update_zuc_module_regs[7] + update_zuc_module_regs[6] + update_zuc_module_regs[5] +
				      update_zuc_module_regs[4] + update_zuc_module_regs[3] + update_zuc_module_regs[2] +
				      update_zuc_module_regs[1] + update_zuc_module_regs[0];
      
      // Per fifox_out message count: 
      // The counter is incremented after ZUC module has added a new message into its fifo_out
      // The counter is decremented once a message has been read from fifo_out to sbu2pci
      // Exception: Do nothing if neither or both of inc and dec are asserted:
      // Counter 0:
      if      ( (update_fifo_out_regs && (current_fifo_out_id == 0)) && ~update_zuc_module_regs[0])
	fifo0_out_message_count <= fifo0_out_message_count - 1;
      else if (~(update_fifo_out_regs && (current_fifo_out_id == 0)) &&  update_zuc_module_regs[0])
	fifo0_out_message_count <= fifo0_out_message_count + 1;
      else 
	// Do nothing
	begin
	end

      // Counter 1:
      if      ( (update_fifo_out_regs && (current_fifo_out_id == 1)) && ~update_zuc_module_regs[1])
	fifo1_out_message_count <= fifo1_out_message_count - 1;
      else if (~(update_fifo_out_regs && (current_fifo_out_id == 1)) &&  update_zuc_module_regs[1])
	fifo1_out_message_count <= fifo1_out_message_count + 1;
      else 
	// Do nothing
	begin
	end
      
      // Counter 2:
      if      ( (update_fifo_out_regs && (current_fifo_out_id == 2)) && ~update_zuc_module_regs[2])
	fifo2_out_message_count <= fifo2_out_message_count - 1;
      else if (~(update_fifo_out_regs && (current_fifo_out_id == 2)) &&  update_zuc_module_regs[2])
	fifo2_out_message_count <= fifo2_out_message_count + 1;
      else 
	// Do nothing
	begin
	end

      // Counter 3:
      if      ( (update_fifo_out_regs && (current_fifo_out_id == 3)) && ~update_zuc_module_regs[3])
	fifo3_out_message_count <= fifo3_out_message_count - 1;
      else if (~(update_fifo_out_regs && (current_fifo_out_id == 3)) &&  update_zuc_module_regs[3])
	fifo3_out_message_count <= fifo3_out_message_count + 1;
      else 
	// Do nothing
	begin
	end

      // Counter 4:
      if      ( (update_fifo_out_regs && (current_fifo_out_id == 4)) && ~update_zuc_module_regs[4])
	fifo4_out_message_count <= fifo4_out_message_count - 1;
      else if (~(update_fifo_out_regs && (current_fifo_out_id == 4)) &&  update_zuc_module_regs[4])
	fifo4_out_message_count <= fifo4_out_message_count + 1;
      else 
	// Do nothing
	begin
	end

      // Counter 5:
      if      ( (update_fifo_out_regs && (current_fifo_out_id == 5)) && ~update_zuc_module_regs[5])
	fifo5_out_message_count <= fifo5_out_message_count - 1;
      else if (~(update_fifo_out_regs && (current_fifo_out_id == 5)) &&  update_zuc_module_regs[5])
	fifo5_out_message_count <= fifo5_out_message_count + 1;
      else 
	// Do nothing
	begin
	end

      // Counter 6:
      if      ( (update_fifo_out_regs && (current_fifo_out_id == 6)) && ~update_zuc_module_regs[6])
	fifo6_out_message_count <= fifo6_out_message_count - 1;
      else if (~(update_fifo_out_regs && (current_fifo_out_id == 6)) &&  update_zuc_module_regs[6])
	fifo6_out_message_count <= fifo6_out_message_count + 1;
      else 
	// Do nothing
	begin
	end

      // Counter 7:
      if      ( (update_fifo_out_regs && (current_fifo_out_id == 7)) && ~update_zuc_module_regs[7])
	fifo7_out_message_count <= fifo7_out_message_count - 1;
      else if (~(update_fifo_out_regs && (current_fifo_out_id == 7)) &&  update_zuc_module_regs[7])
	fifo7_out_message_count <= fifo7_out_message_count + 1;
      else 
	// Do nothing
	begin
	end


      // per channel last_message_id[]
      // message_id is not modified in non zuc commands
      if (update_fifo_out_regs && current_out_zuccmd)
	begin
	  case (current_fifo_out_chid)
	    0:
	      begin
		// message_id valid bit is also set
		chid0_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    1:
	      begin
		chid1_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    2:
	      begin
		chid2_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    3:
	      begin
		chid3_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    4:
	      begin
		chid4_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    5:
	      begin
		chid5_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    6:
	      begin
		chid6_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    7:
	      begin
		chid7_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    8:
	      begin
		chid8_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    9:
	      begin
		chid9_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    10:
	      begin
		chid10_last_message_id <={4'h8,  current_fifo_out_message_id[11:0]};
	      end
	    11:
	      begin
		chid11_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    12:
	      begin
		chid12_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    13:
	      begin
		chid13_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    14:
	      begin
		chid14_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    15:
	      begin
		chid15_last_message_id <= {4'h8, current_fifo_out_message_id[11:0]};
	      end
	    default: begin
	    end
	  endcase

	end
    end
  end  





  // Select last_message_id[] per pending message in fifox_out
  // The selection below will be used only if the correspondoing fifox_out has a valid full message pending
  //
  // fifo0_out_last_message_id[]:
  always @(*) begin
    case (fifo_out_status[0][7:4]) // select by channel_id
      0:
	begin
	  fifo0_out_last_message_id = chid0_last_message_id;
	end
      1:
	begin
	  fifo0_out_last_message_id = chid1_last_message_id;
	end
      
      2:
	begin
	  fifo0_out_last_message_id = chid2_last_message_id;
	end
      
      3:
	begin
	  fifo0_out_last_message_id = chid3_last_message_id;
	end
      4:
	begin
	  fifo0_out_last_message_id = chid4_last_message_id;
	end
      5:
	begin
	  fifo0_out_last_message_id = chid5_last_message_id;
	end
      
      6:
	begin
	  fifo0_out_last_message_id = chid6_last_message_id;
	end
      
      7:
	begin
	  fifo0_out_last_message_id = chid7_last_message_id;
	end
      8:
	begin
	  fifo0_out_last_message_id = chid8_last_message_id;
	end
      9:
	begin
	  fifo0_out_last_message_id = chid9_last_message_id;
	end
      
      10:
	begin
	  fifo0_out_last_message_id = chid10_last_message_id;
	end
      
      11:
	begin
	  fifo0_out_last_message_id = chid11_last_message_id;
	end
      12:
	begin
	  fifo0_out_last_message_id = chid12_last_message_id;
	end
      13:
	begin
	  fifo0_out_last_message_id = chid13_last_message_id;
	end
      
      14:
	begin
	  fifo0_out_last_message_id = chid14_last_message_id;
	end
      
      15:
	begin
	  fifo0_out_last_message_id = chid15_last_message_id;
	end
      
      default: begin
      end
    endcase
  end

  // fifo1_out_last_message_id[]:
  always @(*) begin
    case (fifo_out_status[1][7:4])
      0:
	begin
	  fifo1_out_last_message_id = chid0_last_message_id;
	end
      1:
	begin
	  fifo1_out_last_message_id = chid1_last_message_id;
	end
      
      2:
	begin
	  fifo1_out_last_message_id = chid2_last_message_id;
	end
      
      3:
	begin
	  fifo1_out_last_message_id = chid3_last_message_id;
	end
      4:
	begin
	  fifo1_out_last_message_id = chid4_last_message_id;
	end
      5:
	begin
	  fifo1_out_last_message_id = chid5_last_message_id;
	end
      
      6:
	begin
	  fifo1_out_last_message_id = chid6_last_message_id;
	end
      
      7:
	begin
	  fifo1_out_last_message_id = chid7_last_message_id;
	end
      8:
	begin
	  fifo1_out_last_message_id = chid8_last_message_id;
	end
      9:
	begin
	  fifo1_out_last_message_id = chid9_last_message_id;
	end
      
      10:
	begin
	  fifo1_out_last_message_id = chid10_last_message_id;
	end
      
      11:
	begin
	  fifo1_out_last_message_id = chid11_last_message_id;
	end
      12:
	begin
	  fifo1_out_last_message_id = chid12_last_message_id;
	end
      13:
	begin
	  fifo1_out_last_message_id = chid13_last_message_id;
	end
      
      14:
	begin
	  fifo1_out_last_message_id = chid14_last_message_id;
	end
      
      15:
	begin
	  fifo1_out_last_message_id = chid15_last_message_id;
	end
      
      default: begin
      end
    endcase
  end

  // fifo2_out_last_message_id[]:
  always @(*) begin
    case (fifo_out_status[2][7:4])
      0:
	begin
	  fifo2_out_last_message_id = chid0_last_message_id;
	end
      1:
	begin
	  fifo2_out_last_message_id = chid1_last_message_id;
	end
      
      2:
	begin
	  fifo2_out_last_message_id = chid2_last_message_id;
	end
      
      3:
	begin
	  fifo2_out_last_message_id = chid3_last_message_id;
	end
      4:
	begin
	  fifo2_out_last_message_id = chid4_last_message_id;
	end
      5:
	begin
	  fifo2_out_last_message_id = chid5_last_message_id;
	end
      
      6:
	begin
	  fifo2_out_last_message_id = chid6_last_message_id;
	end
      
      7:
	begin
	  fifo2_out_last_message_id = chid7_last_message_id;
	end
      8:
	begin
	  fifo2_out_last_message_id = chid8_last_message_id;
	end
      9:
	begin
	  fifo2_out_last_message_id = chid9_last_message_id;
	end
      
      10:
	begin
	  fifo2_out_last_message_id = chid10_last_message_id;
	end
      
      11:
	begin
	  fifo2_out_last_message_id = chid11_last_message_id;
	end
      12:
	begin
	  fifo2_out_last_message_id = chid12_last_message_id;
	end
      13:
	begin
	  fifo2_out_last_message_id = chid13_last_message_id;
	end
      
      14:
	begin
	  fifo2_out_last_message_id = chid14_last_message_id;
	end
      
      15:
	begin
	  fifo2_out_last_message_id = chid15_last_message_id;
	end
      
      default: begin
      end
    endcase
  end

  // fifo3_out_last_message_id[]:
  always @(*) begin
    case (fifo_out_status[3][7:4])
      0:
	begin
	  fifo3_out_last_message_id = chid0_last_message_id;
	end
      1:
	begin
	  fifo3_out_last_message_id = chid1_last_message_id;
	end
      2:
	begin
	  fifo3_out_last_message_id = chid2_last_message_id;
	end
      3:
	begin
	  fifo3_out_last_message_id = chid3_last_message_id;
	end
      4:
	begin
	  fifo3_out_last_message_id = chid4_last_message_id;
	end
      5:
	begin
	  fifo3_out_last_message_id = chid5_last_message_id;
	end
      6:
	begin
	  fifo3_out_last_message_id = chid6_last_message_id;
	end
      7:
	begin
	  fifo3_out_last_message_id = chid7_last_message_id;
	end
      8:
	begin
	  fifo3_out_last_message_id = chid8_last_message_id;
	end
      9:
	begin
	  fifo3_out_last_message_id = chid9_last_message_id;
	end
      10:
	begin
	  fifo3_out_last_message_id = chid10_last_message_id;
	end
      11:
	begin
	  fifo3_out_last_message_id = chid11_last_message_id;
	end
      12:
	begin
	  fifo3_out_last_message_id = chid12_last_message_id;
	end
      13:
	begin
	  fifo3_out_last_message_id = chid13_last_message_id;
	end
      14:
	begin
	  fifo3_out_last_message_id = chid14_last_message_id;
	end
      15:
	begin
	  fifo3_out_last_message_id = chid15_last_message_id;
	end
      
      default: begin
      end
    endcase
  end

  // fifo4_out_last_message_id[]:
  always @(*) begin
    case (fifo_out_status[4][7:4])
      0:
	begin
	  fifo4_out_last_message_id = chid0_last_message_id;
	end
      1:
	begin
	  fifo4_out_last_message_id = chid1_last_message_id;
	end
      2:
	begin
	  fifo4_out_last_message_id = chid2_last_message_id;
	end
      3:
	begin
	  fifo4_out_last_message_id = chid3_last_message_id;
	end
      4:
	begin
	  fifo4_out_last_message_id = chid4_last_message_id;
	end
      5:
	begin
	  fifo4_out_last_message_id = chid5_last_message_id;
	end
      6:
	begin
	  fifo4_out_last_message_id = chid6_last_message_id;
	end
      7:
	begin
	  fifo4_out_last_message_id = chid7_last_message_id;
	end
      8:
	begin
	  fifo4_out_last_message_id = chid8_last_message_id;
	end
      9:
	begin
	  fifo4_out_last_message_id = chid9_last_message_id;
	end
      10:
	begin
	  fifo4_out_last_message_id = chid10_last_message_id;
	end
      11:
	begin
	  fifo4_out_last_message_id = chid11_last_message_id;
	end
      12:
	begin
	  fifo4_out_last_message_id = chid12_last_message_id;
	end
      13:
	begin
	  fifo4_out_last_message_id = chid13_last_message_id;
	end
      14:
	begin
	  fifo4_out_last_message_id = chid14_last_message_id;
	end
      15:
	begin
	  fifo4_out_last_message_id = chid15_last_message_id;
	end
      
      default: begin
      end
    endcase
  end

  // fifo5_out_last_message_id[]:
  always @(*) begin
    case (fifo_out_status[5][7:4])
      0:
	begin
	  fifo5_out_last_message_id = chid0_last_message_id;
	end
      1:
	begin
	  fifo5_out_last_message_id = chid1_last_message_id;
	end
      2:
	begin
	  fifo5_out_last_message_id = chid2_last_message_id;
	end
      3:
	begin
	  fifo5_out_last_message_id = chid3_last_message_id;
	end
      4:
	begin
	  fifo5_out_last_message_id = chid4_last_message_id;
	end
      5:
	begin
	  fifo5_out_last_message_id = chid5_last_message_id;
	end
      6:
	begin
	  fifo5_out_last_message_id = chid6_last_message_id;
	end
      7:
	begin
	  fifo5_out_last_message_id = chid7_last_message_id;
	end
      8:
	begin
	  fifo5_out_last_message_id = chid8_last_message_id;
	end
      9:
	begin
	  fifo5_out_last_message_id = chid9_last_message_id;
	end
      10:
	begin
	  fifo5_out_last_message_id = chid10_last_message_id;
	end
      11:
	begin
	  fifo5_out_last_message_id = chid11_last_message_id;
	end
      12:
	begin
	  fifo5_out_last_message_id = chid12_last_message_id;
	end
      13:
	begin
	  fifo5_out_last_message_id = chid13_last_message_id;
	end
      14:
	begin
	  fifo5_out_last_message_id = chid14_last_message_id;
	end
      15:
	begin
	  fifo5_out_last_message_id = chid15_last_message_id;
	end
      
      default: begin
      end
    endcase
  end

  // fifo6_out_last_message_id[]:
  always @(*) begin
    case (fifo_out_status[6][7:4])
      0:
	begin
	  fifo6_out_last_message_id = chid0_last_message_id;
	end
      1:
	begin
	  fifo6_out_last_message_id = chid1_last_message_id;
	end
      2:
	begin
	  fifo6_out_last_message_id = chid2_last_message_id;
	end
      3:
	begin
	  fifo6_out_last_message_id = chid3_last_message_id;
	end
      4:
	begin
	  fifo6_out_last_message_id = chid4_last_message_id;
	end
      5:
	begin
	  fifo6_out_last_message_id = chid5_last_message_id;
	end
      6:
	begin
	  fifo6_out_last_message_id = chid6_last_message_id;
	end
      7:
	begin
	  fifo6_out_last_message_id = chid7_last_message_id;
	end
      8:
	begin
	  fifo6_out_last_message_id = chid8_last_message_id;
	end
      9:
	begin
	  fifo6_out_last_message_id = chid9_last_message_id;
	end
      10:
	begin
	  fifo6_out_last_message_id = chid10_last_message_id;
	end
      11:
	begin
	  fifo6_out_last_message_id = chid11_last_message_id;
	end
      12:
	begin
	  fifo6_out_last_message_id = chid12_last_message_id;
	end
      13:
	begin
	  fifo6_out_last_message_id = chid13_last_message_id;
	end
      14:
	begin
	  fifo6_out_last_message_id = chid14_last_message_id;
	end
      15:
	begin
	  fifo6_out_last_message_id = chid15_last_message_id;
	end
      
      default: begin
      end
    endcase
  end

  // fifo7_out_last_message_id[]:
  always @(*) begin
    case (fifo_out_status[7][7:4])
      0:
	begin
	  fifo7_out_last_message_id = chid0_last_message_id;
	end
      1:
	begin
	  fifo7_out_last_message_id = chid1_last_message_id;
	end
      2:
	begin
	  fifo7_out_last_message_id = chid2_last_message_id;
	end
      3:
	begin
	  fifo7_out_last_message_id = chid3_last_message_id;
	end
      4:
	begin
	  fifo7_out_last_message_id = chid4_last_message_id;
	end
      5:
	begin
	  fifo7_out_last_message_id = chid5_last_message_id;
	end
      6:
	begin
	  fifo7_out_last_message_id = chid6_last_message_id;
	end
      7:
	begin
	  fifo7_out_last_message_id = chid7_last_message_id;
	end
      8:
	begin
	  fifo7_out_last_message_id = chid8_last_message_id;
	end
      9:
	begin
	  fifo7_out_last_message_id = chid9_last_message_id;
	end
      10:
	begin
	  fifo7_out_last_message_id = chid10_last_message_id;
	end
      11:
	begin
	  fifo7_out_last_message_id = chid11_last_message_id;
	end
      12:
	begin
	  fifo7_out_last_message_id = chid12_last_message_id;
	end
      13:
	begin
	  fifo7_out_last_message_id = chid13_last_message_id;
	end
      14:
	begin
	  fifo7_out_last_message_id = chid14_last_message_id;
	end
      15:
	begin
	  fifo7_out_last_message_id = chid15_last_message_id;
	end
      
      default: begin
      end
    endcase
  end

  // At the end of an Ethernet message, its first line in input buffer is updated with message related metadata
  assign input_buffer_wadrs = (~current_in_pkt_type && current_in_message_status_update) ? current_in_message_status_adrs : current_in_tail;
  assign input_buffer_radrs = current_out_head;

  // Written data to input buffer.
  // Adding specific implementation info at the message header[31:0]
  assign input_buffer_wdata = packet_in_progress
			      ?

			      (~current_in_pkt_type && current_in_message_status_update)
				? 
			      // At end of message reception: Updating first message line with eth_header and related message metadata :
			      {current_in_pkt_type, 3'h0, current_in_eth_header, 116'b0,
			       pci2sbu_axi4stream_tuser[67:56], 

                               // [47:0]: Place holder for message metadata. See input_buffer_meta_wdata[]
			       48'b0}

			         :
			      // Message payload:
			      {2'h0, current_in_eom & pci2sbu_axi4stream_tlast, 1'b0, pci2sbu_axi4stream_tdata}

			      :
			      
			      // Message header:
			      {current_in_pkt_type, 1'b0, current_in_eom & pci2sbu_axi4stream_tlast, current_in_som, // metadata
			       pci2sbu_axi4stream_tdata[511:160],
			       100'b0, // reserved
                               pci2sbu_axi4stream_tuser[67:56],

                               // [47:0]: Place holder for message metadata. See input_buffer_meta_wdata[]
			       48'b0};


  
  assign input_buffer_meta_wadrs = current_in_message_status_update ? current_in_message_status_adrs : current_in_tail;
  // Adding the read message id & status into its placeholder in input_buffer_meta_rdata:
  assign input_buffer_meta_wdata = {current_in_opcode,                                       // [47:40]
				    current_in_message_size,                                 // [39:24]
				    current_in_chid,                                         // [23:20]
				    current_in_message_ok ? current_in_message_id : 12'h000, // [19:8]
				    current_in_message_status                                // [7:0]
				    }; 
  assign input_buffer_rdata = input_buffer_rd;

// AFU input buffer 8K x 516b (115 x 36kb BRAMs):
blk_mem_SimpleDP_8Kx512b zuc_input_buffer_data (
  .clka(clk),                              // input wire clka
  .ena(input_buffer_wren),                 // input wire ena
  .wea(input_buffer_write),                // input wire [0 : 0] wea
  .addra(input_buffer_wadrs),              // input wire [12 : 0] addra
  .dina(input_buffer_wdata),               // input wire [515 : 0] dina
  .clkb(clk),                              // input wire clkb
  .enb(input_buffer_rden),                 // input wire enb
  .addrb(input_buffer_radrs),              // input wire [12 : 0] addrb
  .doutb(input_buffer_rd)                  // output wire [515 : 0] doutb
  );

// AFU input buffer metadata, 8K x 48b (11 x 36Kb BRAMs):
// Writing: All writes to input_buffer_data are also written here, using same wadrs and write signals.
//          Upon end of message (TUSER[EOM]), the message metadata is written only to this buffer, to its first buffer address
// Reading: Always along with reading the input_buffer_data array, using the same read address.
// Message metadata format:
// [47:40]   Opcode, as captured from "message_opcode" field in message header
// [39:24]   Message size (bytes), as captured from "message_size" field in message header
// [23:20]   Channel ID
// [19:8]    Message ID
// [7:0]     Message status:
//           [7:3] Reserved
//           [2]   Message is too long (> 9KB)
//           [1]   Mismatching message length
//                 The actual message length (in flits) is compared against the reported length (mesasge_header[495:480])
//                 If no match, this message will be dropped (or bypassed) down the road.
//           [0]   Message is too long (> 9KB)
input_buffer_status_simpleDP_8Kx8b zuc_input_buffer_metadata (
  .clka(clk),                              // input wire clka
  .ena(input_buffer_wren),                 // input wire ena
  .wea(input_buffer_meta_write),           // input wire [0 : 0] wea
  .addra(input_buffer_meta_wadrs),         // input wire [12 : 0] addra
  .dina(input_buffer_meta_wdata),          // input wire [47 : 0] dina
  .clkb(clk),                              // input wire clkb
  .enb(input_buffer_rden),                 // input wire enb
  .addrb(input_buffer_radrs),              // input wire [12 : 0] addrb
  .doutb(input_buffer_meta_rdata)          // output wire [47 : 0] doutb
  );
  

  
// zuc modules instances
generate
  genvar i;
  for (i = 0; i < NUM_MODULES ; i = i + 1) begin: zuc_modules
    zuc_module_wrapper zuc_module_wrapper_inst (
        .clk(clk),
        .reset(reset || afu_reset),
        .zmw_module_id(i),                               // input wire [3:0]
        .zmw_module_in_id(current_fifo_in_id),           // input wire [2:0]
        .zmw_module_in_valid(module_in_valid),           // input wire
        .zmw_in_ready(fifo_in_ready[i]),                 // output wire
        .zmw_in_data(module_in_data[511:0]),             // input wire [511:0]. TBD: Widen fifox_in to 516 bits
        .zmw_in_last(current_out_last),                  // input wire
        .zmw_in_user(current_fifo_in_message_type),      // input wire
        .zmw_in_test_mode(module_in_test_mode),          // input wire. Common to all modules
        .zmw_in_force_modulebypass(module_in_force_modulebypass),    // input wire. Common to all modules
        .zmw_in_force_corebypass(module_in_force_corebypass),    // input wire. Common to all modules
        .zmw_fifo_in_data_count(fifo_in_data_count[i]),  // output wire [9:0]
        .zmw_out_valid(fifo_out_valid[i]),               // output wire
        .zmw_module_out_id(current_fifo_out_id[2:0]),    // input wire [2:0]
        .zmw_module_out_ready(module_out_ready),         // input wire
        .zmw_out_data(fifo_out_data[i][511:0]),          // output wire [511:0]
        .zmw_out_last(fifo_out_last[i]),                 // output wire
        .zmw_out_user(fifo_out_user[i]),                 // output wire
        .zmw_out_status_valid(fifo_out_status_valid[i]), // output wire
        .zmw_out_status_ready(module_out_status_ready),  // input wire
        .zmw_out_status_data(fifo_out_status[i]),        // output wire [7:0]
        .zmw_update_regs(update_zuc_module_regs[i]),     // output wire
        .zmw_in_watermark(module_fifo_in_watermark[i]),  // input wire [4:0]
        .zmw_in_watermark_met(module_fifo_in_watermark_met[i]),
        .zmw_progress(zuc_progress[i]),                  // output wire [15:0]
        .zmw_out_stats(zuc_out_stats[i])                 // output wire [31:0]
    );
    
  end
endgenerate



//===================================================================================================================================
// Histogram: pci2sbu_packets_size
//===================================================================================================================================
//
  zuc_histo zuc_hist_pci2sbu_packet_size
    (
     .hist_clk(clk),
     .hist_reset(reset || afu_reset),
     .hist_id(HIST_ARRAY_PCI2SBU_PACKETS),               // Input: Histogram Instance ID (identifier)
     .hist_enable(hist_pci2sbu_packet_enable),           // Input: Histogram enable
     .hist_event(hist_pci2sbu_packet_event),             // Input: An event to be captured
     .hist_event_chid(hist_pci2sbu_packet_event_chid),   // Input: Event associated chid
     .hist_event_value(hist_pci2sbu_packet_event_size),  // Input: Event associated weight (i.e: packet size)
     .hist_clear(hist_clear),                            // Input: Clear operation trigger
     .hist_clear_op(hist_clear_op),                      // Input: Clear opcode
     .hist_clear_chid(hist_clear_chid),                  // Input: Clear associated chid
     .hist_clear_array(hist_clear_array),                // Input: Clear associated histogram ID 
     .hist_adrs(axi_raddr[9:2]),                         // Input: Histogram read address[7:0]: {chid[3:0], bucket_num[3:0]}
     .hist_dout(hist_pci2sbu_packet_dout)                // Output: Histogram read data[31:0]
     );


//===================================================================================================================================
// Histogram: pci2sbu_EOMpackets_size
//===================================================================================================================================
//
  zuc_histo zuc_hist_pci2sbu_eompacket_size
    (
     .hist_clk(clk),
     .hist_reset(reset || afu_reset),
     .hist_id(HIST_ARRAY_PCI2SBU_EOMPACKETS),            // Input: Histogram Instance ID (identifier)
     .hist_enable(hist_pci2sbu_eompacket_enable),        // Input: Histogram enable
     .hist_event(hist_pci2sbu_eompacket_event),          // Input: An event to be captured
     .hist_event_chid(hist_pci2sbu_eompacket_event_chid),// Input: Event associated chid
     .hist_event_value(hist_pci2sbu_eompacket_event_size),// Input: Event associated weight (i.e: packet size)
     .hist_clear(hist_clear),                            // Input: Clear operation trigger
     .hist_clear_op(hist_clear_op),                      // Input: Clear opcode
     .hist_clear_chid(hist_clear_chid),                  // Input: Clear associated chid
     .hist_clear_array(hist_clear_array),                // Input: Clear associated histogram ID 
     .hist_adrs(axi_raddr[9:2]),                         // Input: Histogram read address[7:0]: {chid[3:0], bucket_num[3:0]}
     .hist_dout(hist_pci2sbu_eompacket_dout)             // Output: Histogram read data[31:0]
     );


//===================================================================================================================================
// Histogram pci2sbu_messages_size
//===================================================================================================================================
//
  zuc_histo zuc_hist_pci2sbu_message_size
    (
     .hist_clk(clk),
     .hist_reset(reset || afu_reset),
     .hist_id(HIST_ARRAY_PCI2SBU_MESSAGES),              // Input: Histogram Instance ID (identifier)
     .hist_enable(hist_pci2sbu_message_enable),          // Input: Histogram enable
     .hist_event(hist_pci2sbu_message_event),            // Input: An event to be captured
     .hist_event_chid(hist_pci2sbu_message_event_chid),  // Input: Event associated chid
     .hist_event_value(hist_pci2sbu_message_event_size), // Input: Event associated weight (i.e: packet size)
     .hist_clear(hist_clear),                            // Input: Clear operation trigger
     .hist_clear_op(hist_clear_op),                     // Input: Clear opcode
     .hist_clear_chid(hist_clear_chid),                  // Input: Clear associated chid
     .hist_clear_array(hist_clear_array),                // Input: Clear associated histogram ID 
     .hist_adrs(axi_raddr[9:2]),                         // Input: Histogram read address[7:0]: {chid[3:0], bucket_num[3:0]}
     .hist_dout(hist_pci2sbu_message_dout)               // Output: Histogram read data[31:0]
     );


//===================================================================================================================================
// Histogram sbu2pci_responses_size
//===================================================================================================================================
//
  zuc_histo zuc_hist_sbu2pci_response_size
    (
     .hist_clk(clk),
     .hist_reset(reset || afu_reset),
     .hist_id(HIST_ARRAY_SBU2PCI_RESPONSES),             // Input: Histogram Instance ID (identifier)
     .hist_enable(hist_sbu2pci_response_enable),         // Input: Histogram enable
     .hist_event(hist_sbu2pci_response_event),           // Input: An event to be captured
     .hist_event_chid(hist_sbu2pci_response_event_chid), // Input: Event associated chid
     .hist_event_value(hist_sbu2pci_response_event_size),// Input: Event associated weight (i.e: packet size)
     .hist_clear(hist_clear),                            // Input: Clear operation trigger
     .hist_clear_op(hist_clear_op),                      // Input: Clear opcode
     .hist_clear_chid(hist_clear_chid),                  // Input: Clear associated chid
     .hist_clear_array(hist_clear_array),                // Input: Clear associated histogram ID 
     .hist_adrs(axi_raddr[9:2]),                         // Input: Histogram read address[7:0]: {chid[3:0], bucket_num[3:0]}
     .hist_dout(hist_sbu2pci_response_dout)              // Output: Histogram read data[31:0]
     );


//===================================================================================================================================
// pci2sbu sampling buffer
//===================================================================================================================================
//
  wire        unconnected_pci2sbu_sample_arready;
  wire        unconnected_pci2sbu_sample_rvalid;
  wire [1:0]  unconnected_pci2sbu_sample_rresp;
  wire [511:0] pci2sbu_sample_wdata;
  wire [31:0] pci2sbu_sample_rdata;
  wire pci_metadata_sample_enable;
  
  assign pci_metadata_sample_enable = afu_ctrl2[17];
  assign pci2sbu_sample_wdata = {pci2sbu_axi4stream_tdata[511:448],
				 pci_metadata_sample_enable ? timestamp[47:0] : pci2sbu_axi4stream_tdata[447:400],
				 pci2sbu_axi4stream_tdata[399:0]};


`ifdef AFU_PCI2SBU_SAMPLE_EN
zuc_sample_buf afu_pci2sbu_sample_buffer
  (
   .sample_clk(clk),
   .sample_reset(reset),
   .sample_sw_reset(afu_pci_sample_soft_reset),
   .sample_enable(afu_pci2sbu_sample_enable),
   .sample_tdata(pci2sbu_sample_wdata),
   .sample_valid(pci2sbu_axi4stream_vld),
   .sample_ready(pci2sbu_axi4stream_rdy),
   .sample_eom(pci2sbu_axi4stream_tuser[39]),
   .sample_tlast(pci2sbu_axi4stream_tlast),
   .axi4lite_araddr_base(AFU_CLK_PCI2SBU),
   .axi4lite_araddr(axi_raddr),
   .axi4lite_arvalid(axilite_ar_vld),
   .axi4lite_arready(unconnected_pci2sbu_sample_arready),
   .axi4lite_rready(axilite_r_rdy),
   .axi4lite_rvalid(unconnected_pci2sbu_sample_rvalid),
   .axi4lite_rresp(unconnected_pci2sbu_sample_rresp),
   .axi4lite_rdata(pci2sbu_sample_rdata)
   );
`endif //  `ifdef AFU_PCI2SBU_SAMPLE_EN
  
`ifndef AFU_PCI2SBU_SAMPLE_EN
  assign pci2sbu_sample_rdata = 32'hdeadf00d;
`endif  


//===================================================================================================================================
// sampling trigger
//===================================================================================================================================
//
localparam
  SAMPLING_TRIGGER_POSITION = 2*1024; // 2K samples from end of the 8K sampling buffer

  reg  sampling_window;
  wire sampling_trigger_match;
  wire sampling_trigger_enabled;
  reg trigger_is_met;
  reg [15:0] sampling_window_end; // Number of clock rom trigger to end sampling

// Trigger: Temporarily looking for a specific pattern at modue_in_data[]
  assign sampling_trigger_enabled = afu_ctrl2[19];
  
  assign sampling_trigger_match = module_in_valid && (module_in_data[47:0] == {afu_ctrl9[15:0], afu_ctrl8});
  
  always @(posedge clk) begin
    if (reset || afu_reset)
      begin
	sampling_window <= 1'b1;
	trigger_is_met <= 1'b0;
	sampling_window_end <= 16'b0;
      end
    else
      begin
	if (sampling_trigger_match && sampling_trigger_enabled)
	  trigger_is_met <= 1'b1;

	if (trigger_is_met)
	  sampling_window_end <= sampling_window_end + 1'b1;

	if (sampling_window_end > SAMPLING_TRIGGER_POSITION)
	  begin
	    sampling_window <= 1'b0;
	  end
      end
  end
  
  
//===================================================================================================================================
// input_buffer sampling buffer
//===================================================================================================================================
//
  wire [511:0] input_buffer_sample_wdata;
  wire [511:0] input_buffer_sample_rdata;
  wire 	       input_buffer_sample_vld;
  wire 	       input_buffer_sample_rdy;
  wire 	       input_buffer_sample_eom;
  wire 	       input_buffer_sample_last;
  wire 	       unconnected_input_buffer_sample_arready;
  wire 	       unconnected_input_buffer_sample_rvalid;
  wire [1:0]   unconnected_input_buffer_sample_rresp;
  
  assign input_buffer_sample_vld = afu_ctrl2[18] ? 1'b1 : input_buffer_meta_write;
  assign input_buffer_sample_rdy = 1'b1;
  assign input_buffer_sample_eom = pci2sbu_axi4stream_tuser[39];
  assign input_buffer_sample_last = pci2sbu_axi4stream_tlast;
  
  wire [399:0] input_buffer_sample_wmetadata;
  assign input_buffer_sample_wmetadata = {timestamp[47:0],
					  pci2sbu_axi4stream_tuser[39], pci2sbu_axi4stream_tuser[30], pci2sbu_axi4stream_tlast,                // ...
					  current_in_zuccmd, current_in_eom, current_in_som, chid0_in_som, current_in_buffer_full,             // 8
					  current_in_message_ok, 3'b0, current_in_message_status[3:0],                                         // 8
					  input_buffer_watermark_met[15:0],                                                                    // 16
					  6'b0, current_in_message_lines[9:0], 6'b0, chid0_in_message_lines[9:0], 6'b0, current_in_flits[9:0], // 48
					  current_in_message_size[15:0], chid0_in_message_size[15:0],                                          // 32
					  4'b0, current_in_message_id[11:0], 4'b0, chid0_in_message_id[11:0],                                  // 32
					  3'b0, chid0_in_message_start[12:0], 3'b0, current_in_message_start[12:0],                            // 32
					  3'b0, input_buffer_wadrs[12:0], 3'b0, input_buffer_meta_wadrs[12:0],                                 // 32
					  5'b0, current_in_buffer_data_countD[10:0], 5'b0, chid_in_buffer_data_count[0][10:0],                 // 32
					  3'b0, chid0_out_head[12:0], 3'b0, current_out_head[12:0],                                            // 32
					  8'b0,                                                                                                // 8
					  4'b0, current_out_chid[3:0],                                                                         // 8
					  6'b0, chid_in_message_count[0][9:0],                                                                   // 16
					  3'b0, chid0_in_tail[12:0], 3'b0, current_in_tail[12:0],                                              // 32
  					  4'b0, current_in_chid[3:0],                                                                          // 8
					  8'b0};                                                                                               // 8
  
  assign input_buffer_sample_wdata = {input_buffer_wdata[511:448], input_buffer_sample_wmetadata[399:0], input_buffer_meta_wdata[47:0]};
  
`ifdef INPUT_BUFFER_SAMPLE_EN
zuc_sample_buf input_buffer_sample
  (
   .sample_clk(clk),
   .sample_reset(reset),
   .sample_sw_reset(afu_pci_sample_soft_reset),
   .sample_enable(input_buffer_sample_enable),
   .sample_tdata(input_buffer_sample_wdata),
   .sample_valid(input_buffer_sample_vld),
   .sample_ready(input_buffer_sample_rdy),
   .sample_eom(input_buffer_sample_eom),
   .sample_tlast(input_buffer_sample_last),
   .axi4lite_araddr_base(AFU_CLK_INPUT_BUFFER),
   .axi4lite_araddr(axi_raddr),
   .axi4lite_arvalid(axilite_ar_vld),
   .axi4lite_arready(unconnected_input_buffer_sample_arready),
   .axi4lite_rready(axilite_r_rdy),
   .axi4lite_rvalid(unconnected_input_buffer_sample_rvalid),
   .axi4lite_rresp(unconnected_input_buffer_sample_rresp),
   .axi4lite_rdata(input_buffer_sample_rdata)
   );
`endif  

`ifndef INPUT_BUFFER_SAMPLE_EN
  assign input_buffer_sample_rdata = 32'hdeadf00d;
`endif  

  
//===================================================================================================================================
// module_in sampling buffer
//===================================================================================================================================
//
  wire [511:0] module_in_sample_wdata;
  wire [399:0] module_in_sample_wmetadata;
  wire 	       module_in_sample_eom;
  wire [31:0]  module_in_sample_rdata;
  wire 	       unconnected_module_in_sample_arready;
  wire 	       unconnected_module_in_sample_rvalid;
  wire [1:0]   unconnected_module_in_sample_rresp;
  
  // Add (replace) sample metadata to lower sample_data[15:0]
  assign module_in_sample_wmetadata = {timestamp[47:0],                                                                                           // 48
				       40'b0,
				       3'b0, module_in_valid, 2'b0, input_buffer_meta_write, input_buffer_write,			          // 8
				       2'b00, update_channel_out_regs, update_channel_in_regs,                                                    // ...
				       1'b0, packet_in_nstate[2:0], message_out_nstate[3:0], sbu2pci_out_nstate[3:0],                             // 16
				       fifo_in_ready[7],fifo_in_ready[6],fifo_in_ready[5],fifo_in_ready[4],                                       // ...
				       fifo_in_ready[3],fifo_in_ready[2],fifo_in_ready[1],fifo_in_ready[0],                                       // 8
				       current_out_last, current_fifo_in_message_ok, current_fifo_in_header, current_fifo_in_eth_header,          // ...
				       1'b0, current_fifo_in_id[2:0],                                                                             // 8 
				       6'b0, fifo_in_data_count[7][9:0], 6'b0, fifo_in_data_count[6][9:0],                                        // 32
				       6'b0, fifo_in_data_count[5][9:0], 6'b0, fifo_in_data_count[4][9:0],                                        // 32
				       6'b0, fifo_in_data_count[3][9:0], 6'b0, fifo_in_data_count[2][9:0],                                        // 32
				       6'b0, fifo_in_data_count[1][9:0], 6'b0, fifo_in_data_count[0][9:0],                                        // 32
				       8'b0,                                                                                                      // 8
  				       fifo_in_free_regD[7:0],                                                                                    // 8
				       messages_validD[15:0],                                                                                     // 16
				       3'b0, chid0_out_head[12:0], 3'b0, current_out_head[12:0],                                                  // 32
				       8'b0,                                                                                                      // 8
				       4'b0, current_out_chid[3:0],                                                                               // 8
				       6'b0, chid_in_message_count[0][9:0],                                                                         // 16
				       3'b0, chid0_in_tail[12:0], 3'b0, current_in_tail[12:0],                                                    // 32
  				       4'b0, current_in_chid[3:0],                                                                                // 8
				       8'b0};                                                                                                     // 8
  
  
  assign module_in_sample_wdata = {module_in_data[511:448], module_in_sample_wmetadata[399:0], module_in_data[47:0]};
  assign module_in_sample_eom = 1'b1;
  assign module_in_sample_last = current_out_last;
  assign module_in_sample_valid = afu_ctrl2[18] ? 1'b1 : module_in_valid;
  assign module_in_sample_ready = fifo_in_readyD;
  
`ifdef MODULE_IN_SAMPLE_EN
zuc_sample_buf module_in_sample_buffer
  (
   .sample_clk(clk),
   .sample_reset(reset),
   .sample_sw_reset(afu_pci_sample_soft_reset),
   .sample_enable(module_in_sample_enable),
   .sample_tdata(module_in_sample_wdata),
   .sample_valid(module_in_sample_valid),
   .sample_ready(module_in_sample_ready),
   .sample_eom(module_in_sample_eom),
   .sample_tlast(module_in_sample_last),
   .axi4lite_araddr_base(AFU_CLK_MODULE_IN),
   .axi4lite_araddr(axi_raddr),
   .axi4lite_arvalid(axilite_ar_vld),
   .axi4lite_arready(unconnected_module_in_sample_arready),
   .axi4lite_rready(axilite_r_rdy),
   .axi4lite_rvalid(unconnected_module_in_sample_rvalid),
   .axi4lite_rresp(unconnected_module_in_sample_rresp),
   .axi4lite_rdata(module_in_sample_rdata)
   );
`endif  

`ifndef MODULE_IN_SAMPLE_EN
  assign module_in_sample_rdata = 32'hdeadf00d;
`endif  

//===================================================================================================================================
// sbu2pci sampling buffer
//===================================================================================================================================
//
  wire        unconnected_sbu2pci_sample_arready;
  wire        unconnected_sbu2pci_sample_rvalid;
  wire [1:0]  unconnected_sbu2pci_sample_rresp;
  wire [31:0] sbu2pci_sample_rdata;
  wire [511:0] sbu2pci_sample_wdata;
  wire [399:0] sbu2pci_sample_wmetadata;

  assign sbu2pci_sample_wmetadata = {timestamp[47:0],                                                                     // 48
				     16'b0,                                                                               // 16
				     fifo7_out_last_message_id[15:0], fifo7_out_message_id[11:0],                         // ...
				     fifo6_out_last_message_id[15:0], fifo6_out_message_id[11:0],                         // ...
				     fifo5_out_last_message_id[15:0], fifo5_out_message_id[11:0],                         // ...
				     fifo4_out_last_message_id[15:0], fifo4_out_message_id[11:0],                         // ...
				     fifo3_out_last_message_id[15:0], fifo3_out_message_id[11:0],                         // .. .
				     fifo2_out_last_message_id[15:0], fifo2_out_message_id[11:0],                         // ...
				     fifo1_out_last_message_id[15:0], fifo1_out_message_id[11:0],                         // ...
				     fifo0_out_last_message_id[15:0], fifo0_out_message_id[11:0],                         // 32x7
				     3'b0, fifo7_out_message_count[8:0], 3'b0, fifo6_out_message_count[8:0],              // ...
				     3'b0, fifo5_out_message_count[8:0], 3'b0, fifo4_out_message_count[8:0],              // ...
				     3'b0, fifo3_out_message_count[8:0], 3'b0, fifo2_out_message_count[8:0],              // ...
				     3'b0, fifo1_out_message_count[8:0], 3'b0, fifo0_out_message_count[8:0],              // 32x3
				     current_fifo_out_id[3:0], fifo_out_id_delta[3:0], fifo_out_message_valid_regD[7:0]}; // 16
  
  assign sbu2pci_sample_wdata = {sbu2pci_axi4stream_tdata[511:448],
				 pci_metadata_sample_enable ? sbu2pci_sample_wmetadata : sbu2pci_axi4stream_tdata[447:48],
				 sbu2pci_axi4stream_tdata[47:0]};

`ifdef AFU_SBU2PCI_SAMPLE_EN
zuc_sample_buf afu_sbu2pci_sample_buffer
  (
   .sample_clk(clk),
   .sample_reset(reset),
   .sample_sw_reset(afu_pci_sample_soft_reset),
   .sample_enable(afu_sbu2pci_sample_enable),
   .sample_tdata(sbu2pci_sample_wdata),
   .sample_valid(sbu2pci_axi4stream_vld),
   .sample_ready(sbu2pci_axi4stream_rdy),
   .sample_eom(sbu2pci_axi4stream_tuser[39]),
   .sample_tlast(sbu2pci_axi4stream_tlast),
   .axi4lite_araddr_base(AFU_CLK_SBU2PCI),
   .axi4lite_araddr(axi_raddr),
   .axi4lite_arvalid(axilite_ar_vld),
   .axi4lite_arready(unconnected_sbu2pci_sample_arready),
   .axi4lite_rready(axilite_r_rdy),
   .axi4lite_rvalid(unconnected_sbu2pci_sample_rvalid),
   .axi4lite_rresp(unconnected_sbu2pci_sample_rresp),
   .axi4lite_rdata(sbu2pci_sample_rdata)
   );
`endif  

`ifndef AFU_SBU2PCI_SAMPLE_EN
  assign sbu2pci_sample_rdata = 32'hdeadf00d;
`endif  

endmodule
