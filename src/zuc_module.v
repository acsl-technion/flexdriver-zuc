// zuc module
// A message is read from fifo_in and delivered to zuc core, then aggregated into fifo_out.
// This scheme is triggered if there is at least one full message in fifo_in, and there is sufficient space in fifo_out to hold the resulting response.
//    incoming message size is extracted from first fifo_in line (message header, see below)
//    fifo_out free count is locally calculated:  == MODULE_FIFO_OUT_SIZE - fifo_out_data_count[]
// The expected space in fifo_out depends on the incoming message size & command:
// 1. If (command == Confidentiality), then expected fifo_out space is >= fifo_in message_size
// 2. If (command == Integrity), then expected fifo_out space is constant 512b, 1 fifo_out line
//
// First line read from fifo_in is the message header:
//
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
// 415:0       Reserved
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
// 415:160     Reserved
// 159:128     MAC
// 127:0       Reserved (tkeep = 128'b0)
//
//
// ==============================================================================
// Internal AFU message header info:
// Generated locally, and transferred between the AFU modules.
// Required for proper and/or simplified implementation  	    
// ==============================================================================
// header[]  | Field         | Description
// ----------+--------------------------------------------------------------------
// [515:511]   TBD: Add these bits to all intermmediate fifos: {2'b00, EOM, SOM}
// [511:160]   pci2sbu_tdata[511:160]
// [31:20]     pci2sbu_axi4stream_tuser[67:56]
// [19:8]      current_in_message_id[11:0]
// [7:4]       current_in_context[3:0]
// [3:0]       current_in_chid[3:0]
//
module zuc_module (
		   input wire 	       zm_clk,
		   input wire 	       zm_reset,
		   input wire 	       zm_in_valid,
		   output wire 	       zm_in_ready,
		   input wire [511:0]  zm_in_data,
		   input wire 	       zm_in_last,
		   input wire 	       zm_in_user,
		   input wire 	       zm_in_test_mode,
		   input wire 	       zm_in_force_modulebypass,
		   input wire 	       zm_in_force_corebypass,
		   input wire [9:0]    fifo_in_data_count,
		   input wire [9:0]    fifo_out_data_count,
		   output wire 	       zm_out_valid,
		   input wire 	       zm_out_ready,
		   output wire [511:0] zm_out_data,
		   output wire [63:0]  zm_out_keep, // generated locally, based on message length 
		   output wire 	       zm_out_last,
		   output reg 	       zm_out_user,
		   output reg 	       zm_out_status_valid,
		   input 	       zm_out_status_ready,
		   output reg [7:0]    zm_out_status_data,
		   output wire 	       zm_update_module_regs,
		   input wire [4:0]    zm_in_watermark,
		   output wire 	       zm_in_watermark_met,
		   output reg [15:0]   zm_progress,
		   output reg [31:0]   zm_out_stats
  );

  
`include "zuc_params.v"

  reg [63:0]  zm_idle;
  reg [7:0]   zm_cmd;
  reg [3:0]   zm_response_status;
  reg [511:0] zm_text_in_reg;
  reg [5:0]   zm_text_32b_index;
  reg [7:0]   zm_core_out_count;
  wire [15:0] fifo_out_free_count;
  wire 	      fifo_out_free;
  reg [31:0]  zm_mac_reg;
  reg [95:0]  zm_keystream96;
  reg [31:0]  zm_keystreamQ;
  reg [15:0]  zm_in_message_size;
  reg [15:0]  zm_in_message_bits;
  reg [15:0]  zm_in_message_csize;
  reg [15:0]  zm_in_message_isize;
  reg [15:0]  zm_in_message_lines;
  reg [15:0]  zm_message_size_inprogress;
  reg 	      zm_in_readyQ;
  reg 	      zm_done;

  // Module test mode: Writing intermmediate lfsr values & keystream words to fifo_out
  reg [511:0] zm_test_mode_keystream;
  reg 	      zm_test_mode_keystream_valid;
  wire [511:0] zm_test_mode_lfsr;
  wire 	       zm_test_mode_lfsr_valid;
  reg	       zm_test_mode_text_in_valid;
  wire [511:0] zm_test_mode_data;
  wire 	       zm_test_mode_data_valid;
 
  reg 	      zm_bypass_or_header_valid;
  reg 	      zm_bypass_or_header;
  reg [1:0]   zm_wait_keystream;
  reg	      zm_update_module_regsQ;
  reg 	      zm_core_valid;
  reg [3:0]   zm_channel_id;
  reg [5:0]   zm_init_count;
  reg 	      zm_core_last;
  reg [63:0]  zm_core_keep; // TBD: Save this register by directly driving sbu2pci_tkeep via wires
  reg [63:0]  zm_core_util; // TBD: Save this register by directly driving sbu2pci_tkeep via wires
  reg [63:0]  zm_core_elapsed_time; // TBD: Save this register by directly driving sbu2pci_tkeep via wires
  reg [47:0]  zm_core_busy_time; // TBD: Save this register by directly driving sbu2pci_tkeep via wires
  reg [31:0]  zm_clc_freq;
  
  reg [3:0]   zuc_module_nstate;

  reg [511:0] zm_out_accum_reg;
  reg [511:0] zm_in_header;

  reg [31:0] zm_mac0;
  reg [31:0] zm_mac1;
  reg [31:0] zm_mac2;
  reg [31:0] zm_mac3;
  reg [31:0] zm_mac4;
  reg [31:0] zm_mac5;
  reg [31:0] zm_mac6;
  reg [31:0] zm_mac7;
  reg [31:0] zm_mac8;
  reg [31:0] zm_mac9;
  reg [31:0] zm_mac10;
  reg [31:0] zm_mac11;
  reg [31:0] zm_mac12;
  reg [31:0] zm_mac13;
  reg [31:0] zm_mac14;
  reg [31:0] zm_mac15;
  reg [31:0] zm_mac16;
  reg [31:0] zm_mac17;
  reg [31:0] zm_mac18;
  reg [31:0] zm_mac19;
  reg [31:0] zm_mac20;
  reg [31:0] zm_mac21;
  reg [31:0] zm_mac22;
  reg [31:0] zm_mac23;
  reg [31:0] zm_mac24;
  reg [31:0] zm_mac25;
  reg [31:0] zm_mac26;
  reg [31:0] zm_mac27;
  reg [31:0] zm_mac28;
  reg [31:0] zm_mac29;
  reg [31:0] zm_mac30;
  reg [31:0] zm_mac31;
  reg [31:0] zm_mac_0_7;
  reg [31:0] zm_mac_8_15;
  reg [31:0] zm_mac_16_23;
  reg [31:0] zm_mac_24_31;
  reg [31:0] zm_mac_0_31;

  reg [127:0] zm_iv;               // Initializatioin Vector
  reg [127:0] zm_key;              // Initialization Key
  reg 	      zm_go;               // zuc_core is triggered to start. Asserted after all inputs (IV, Key, pc_text) are ready
  reg 	      zm_go_asserted;      // zuc_core is triggered to start. Asserted after all inputs (IV, Key, pc_text) are ready
  wire [31:0] zm_keystream;        // holding flipped bytes of zm_keystream_out
  wire 	      zm_keystream_valid;  // Output - a valid 32bit output text on zm_keystream. Valid for 1 clock
  wire [63:0] zm_bypass_keep;
  reg [95:0]  zm_keystream96_lastkey; // holding last keystream, from position LENGTH (GET_WORD(keystream[], LENGTH))
  reg [3:0]   mac_bytes;
  reg [31:0]  cipher_bytes;
  
  assign zm_update_module_regs = zm_update_module_regsQ;
  
  // TBD: Verify replacing this 'free_count' scheme
  assign fifo_out_free_count = MODULE_FIFO_OUT_SIZE - {6'h00, fifo_out_data_count};
  // *out_free count should be bigger (rather than GE) than *message_lines, to account for the header line as well 
  assign fifo_out_free = (fifo_out_free_count > zm_in_message_lines) ? 1'b1 : 1'b0;

  // fifo_in watermark
  // Incoming messages are handled (movede to zuc_core), once the specified watermark has been exceeded.
  // zm_in_watermark[4:0]:
  //      [4]   - A new watermark is present at zm_in_watermark[3:0]. This indication is valid for 1 clock only !!
  //              
  //    [3:0]   - zm_in_watermark_data
  //              Fifo_in capacity high watermark, 32 fifo lines (2KB) per tick. Default 0
  //              The transfer from fifo_in to zuc_core is held until this watermark is exceeded.
  //              This capability is aimed for testing the zuc_cores utilization & tpt:
  //              1. To utilize all zuc_cores, there is a need to apply the messages to the cores as fast as possible.
  //              2. To eliminate the dependence on pci2sbu incoming messages rate, we accumulate into fifo_in first
  //              3. Once the watermark is exceeded, the messages are fed to the zuc cores at full speed (512b/clock). 
  //              Usage Note: This watermark is effective only once, immediateley after writing afu_ctrl1.
  //                          To reactivate, rewrite to afu_ctrl1 is required 
  reg 	      zm_in_watermark_valid;
  wire 	      zm_in_watermark_hit;
  wire 	      zm_in_message_valid;
  assign zm_in_watermark_hit = (fifo_in_data_count >= {1'b0, zm_in_watermark[3:0], 5'h00}) ? 1'b1 : 1'b0;
  assign zm_in_message_valid = zm_in_valid & zm_in_watermark_valid;
  assign zm_in_watermark_met = zm_in_watermark_valid;

  always @(posedge zm_clk) begin
    if (zm_reset) begin
      zm_in_watermark_valid <= 1; // Default zero watermark is assumed, thus messages are allowed from fifo_in to zuc_core following reset 
    end
    else
      begin
      if (zm_in_watermark[4])
	zm_in_watermark_valid <= 1'b0;
      if (zm_in_watermark_hit)
	zm_in_watermark_valid <= 1'b1;
      end
  end


  
  // zuc_core input ctrl:
  localparam [3:0]
    ZM_IDLE                   = 4'b0000,
    ZM_BYPASS_ETH_HEADER      = 4'b0001,
    ZM_SAMPLE_MESSAGE_HEADER  = 4'b0010,
    ZM_WAIT_FIFO_OUT          = 4'b0011,
    ZM_BYPASS_MESSAGE_HEADER  = 4'b0100,
    ZM_INIT                   = 4'b0101,
    ZM_RUN_C                  = 4'b0110,
    ZM_WAIT_2KEYS             = 4'b0111,
    ZM_RUN_I                  = 4'b1000,
    ZM_MAC1                   = 4'b1001,
    ZM_MAC2                   = 4'b1010,
    ZM_BYPASS                 = 4'b1011,
    ZM_STATUS                 = 4'b1100,
    ZM_END                    = 4'b1101;
  
  always @(posedge zm_clk) begin
    if (zm_reset) begin
      zuc_module_nstate <= ZM_IDLE;
      zm_in_message_size <= 16'h000;
      zm_in_message_bits <= 16'h000;
      zm_message_size_inprogress <= 16'h0000;
      zm_in_readyQ <= 1'b0;
      zm_core_last <= 1'b0;
      zm_core_valid <= 1'b0;
      zm_response_status <= 4'h0; // Default OK status
      zm_go <= 0;
      zm_go_asserted <= 0;
      zm_done <= 1'b0;
      zm_text_32b_index <= 0;
      zm_bypass_or_header_valid <= 1'b0;
      zm_bypass_or_header <= 1'b0;
      zm_wait_keystream <= 2'b11;
      zm_mac_reg <= 32'h00000000;
      zm_keystream96[95:0] <= 96'h0000000000000000;
      zm_out_status_data <= 8'h00;
      zm_out_status_valid <= 1'b0;
      zm_text_in_reg  <= 512'b0;
      zm_out_accum_reg <= 512'b0;
      zm_idle <= 64'h0000000000000000;
      
      // ???? Keep note that there are 4 such signals, one per zuc module instantiation.
      //      Revisit the method for updating zuc_out_message_count registers  
      zm_update_module_regsQ <= 1'b0; // update zuc module message_count

      // Reporting zuc operation progress.
      // Used by zuc_afu to track the zuc_module total_load.
      // zuc_modules total_load is then used for a load based input_buffer to fifox_in arbitration
      //
      // zm_progress[15:0]:
      // [3:0] - Reporting a micro operation completed: 
      //       0001 - C/I/Bypass operation: overhead is done
      //       0010 - C/I/Bypass operation: another 512b line is done
      //       x1xx - reserved
      //       1xxx - reserved
      // [7:4]  - zuc command
      // [15:8] - last_word index within a 512b line 
      zm_progress <= 16'h00;
      zm_test_mode_keystream_valid <= 1'b0;
      zm_test_mode_text_in_valid <= 1'b0;
    end

    else 
      begin
	case (zuc_module_nstate)
	  ZM_IDLE:
	    begin
	      zm_idle <= zm_idle +1; // idle duration counter

	      // zuc module is triggered by zm_in_message_valid.
	      // fifo_in is configured as a packet_fifo, thus zm_in_message_valid means there is at least one full message in fifo_in
	      // fifo_in contains 1 or more packets, where 1 packet means 1 message. 
	      if (zm_in_message_valid)	      
		begin
		zm_out_user <= zm_in_user;
		  if (zm_in_user)
		    begin
		      zuc_module_nstate <= ZM_SAMPLE_MESSAGE_HEADER;
		    end
		  
		  else if (~zm_in_user && zm_out_ready)
		    // An Ethernet header: If fifo_out is not full, bypass the eth header to fifo_out
		    begin
		      zm_bypass_or_header <= 1'b1;
		      zm_in_readyQ <= 1'b1;
		      zm_bypass_or_header_valid <= 1'b1;
		      zuc_module_nstate <= ZM_BYPASS_ETH_HEADER;
		    end
		end
	    end
	  
	  ZM_BYPASS_ETH_HEADER:
	    begin
	      zm_in_readyQ <= 1'b0;
	      zm_bypass_or_header <= 1'b0;
	      zm_bypass_or_header_valid <= 1'b0;
	      zuc_module_nstate <= ZM_SAMPLE_MESSAGE_HEADER;
	    end // else: !if(zm_reset)
    
	  ZM_SAMPLE_MESSAGE_HEADER:
	    begin
	      // Sampling related message header info. The header is still NOT dropped from fifo_in.
	      // In CMD_INTEG command, the headr is NOT bypassed to zm_out_data. Instead, it is sampled here, to be merged with the final MAC
	      // We get here ether directly from IDLE or after bypassing an eth header.
	      // If fifo_in has been read (to drop the eth header), we need to verify that next fifo_in line is valid,
	      // before sampling mesage header info

	      if (zm_in_valid)
		begin
		  
		  zm_in_header <= zm_in_data;
		  zm_in_message_size <= zm_in_data[495:480] + 'd64; // Message size in bytes, including header line
		  zm_in_message_bits <= zm_in_data[495:480] << 3; // Message size in bits
		  
		  // Integrity & Confidentiality effective message length, where LENGTH is message length in bits:
		  // C: L = (LENGTH+31)/32; 
		  // I: N = LENGTH + 64; L = (N + 31) / 32; // LENGTH is message length in bits
		  zm_in_message_csize <= (zm_in_data[495:480] + 3) >> 2;  // Message size, adjusted to zuc confidentiality keystream length in 32b ticks
		  zm_in_message_isize <= (zm_in_data[495:480] + 11) >> 2; // Message size, adjusted to zuc integrity keystream length in 32b ticks
		  
		  zm_in_message_lines <= {6'h00, zm_in_data[495:486]} + (zm_in_data[485:480] > 0); // Message size in 512b ticks
		  zm_cmd <= zm_in_force_modulebypass ? MESSAGE_CMD_MODULEBYPASS : zm_in_data[511:504];
		  zm_key <= zm_in_data[415:288];
		  zm_iv <= zm_in_data[287:160];
		  zm_channel_id[3:0] <= zm_in_data[23:20]; //  TBD: Verify input buffer CTRL adds channel_id to fifox_in
		  zm_init_count <= 6'h00;
		  zm_mac_reg <= 32'h00000000; // Prior to MAC calculation, initial MAC should be cleared
		  zuc_module_nstate <= ZM_WAIT_FIFO_OUT;
		end
	    end
	  
	  ZM_WAIT_FIFO_OUT:
	    begin
	      case (zm_cmd)
		MESSAGE_CMD_CONF:
		  begin
		    // Verify there is sufficient space in fifo_out to host the expected response
		    // zm_in_message_lines - number of full 512b occupying the message 
		    if (zm_out_ready && fifo_out_free)
		      begin
			zm_bypass_or_header <= 1'b1;
			zuc_module_nstate <= ZM_BYPASS_MESSAGE_HEADER;
		      end
		    // else
		    //    wait for sufficient space in fifo_out
		  end
		
		MESSAGE_CMD_INTEG:
		  begin
		    // CMD_INTEG response is a single 512b line,
		    //    which is the merge of final MAC and the previously sampled zm_in_header
		    // The header is not bypassed to zm_out_data, so going directly to INIT.
		    if (zm_out_ready)
		      begin
			// At least 1 free line in fifo_out
			if (zm_in_test_mode && zm_in_user)
			  // In RDMA message the INTEG response header is NOT written now but rather at the end.
			  // Yet, in test mode, we do need to write the header, such that the subsequent test_mode
			  // data writes will follow a "familiar" header.
			  // Otherwise (without a leading header), the sbu2pci SM won't recognize this response message
			  // Eventually an RDMA INTEG response will have the header twice: at the beginning and at the end,
			  // while only the second header will include the final MAC. 
			  begin
			    zm_bypass_or_header <= 1'b1;
			    zuc_module_nstate <= ZM_BYPASS_MESSAGE_HEADER;
			  end
			else
			  begin
			    // Drop header line from fifo_in, without bypass to zm_out_data
			    zm_in_readyQ <= 1'b1;
			    zuc_module_nstate <= ZM_INIT;
			  end
		      end
 		  end
		
		MESSAGE_CMD_MODULEBYPASS:
		  begin
		    // Verify there is sufficient space in fifo_out to host the bypassed message
		    if (zm_out_ready && fifo_out_free)
		      begin
			zm_bypass_or_header <= 1'b1;
			zuc_module_nstate <= ZM_BYPASS;
		      end
		    // else
		    // Stay here, wait for sufficient space in fifo_out
		  end
		
		default:
		  begin
		    // Illegal opcode: Bypass the message to fifo_out
		    // zuc_module is not supposed to "see" illegal opcodes, but just in case...
		    // Verify there is sufficient space in fifo_out to host the bypassed message
		    if (zm_out_ready && fifo_out_free)
		      begin
			zm_bypass_or_header <= 1'b1;
			zuc_module_nstate <= ZM_BYPASS;
		      end
		    // else
		    // Stay here, wait for sufficient space in fifo_out
		  end
	      endcase // case (zm_cmd)
	    end
	  
	  ZM_BYPASS_MESSAGE_HEADER:
	    begin
	      // During this clock, the message header (zm_in_data[]) is bypassed to zm_out_data, which is then written to fifo_out.
	      
	      // Drop current line from fifo_in 
	      zm_in_readyQ <= 1'b1;
	      zm_bypass_or_header_valid <= 1'b1;
	      zuc_module_nstate <= ZM_INIT;
	    end
	  
	  ZM_INIT:
	    begin
	      zm_go <= 1'b1; // start zuc_core
	      zm_go_asserted <= 1'b1;
	      zm_bypass_or_header <= 1'b0;
	      zm_bypass_or_header_valid <= 1'b0;

	      // Wait for
	      // 1 clock LFSR init
	      // 32+1 clocks LFSRInit iterations
	      // 2 more clocks for first keystream_valid
	      if (zm_init_count >= 36)
		begin
		  // Message header line already dropped, and first payload line is avaiable at zm_in_data.
		  // No need to check for zm_in_message_valid. fifo_in is guaranteed to have the whole message (minimum of two 512b lines)
		  zm_text_in_reg <= zm_in_data;
		  zm_in_readyQ <= 1'b1;
		  zm_progress <= {8'h00, zm_cmd[3:0], 4'b0001};
		  zm_wait_keystream <= 2'b11;

		  zm_text_32b_index <= 6'h00;
		  zm_message_size_inprogress <= 16'h0000;
		  zm_keystream96[95:0] <= 96'h0000000000000000;

		  // Module test mode: Dump latter read text_in_reg to zm_out
		  zm_test_mode_text_in_valid <= zm_in_test_mode ? 1'b1 : 1'b0;
		  zuc_module_nstate <= (zm_cmd == MESSAGE_CMD_CONF) ? ZM_RUN_C : ZM_WAIT_2KEYS;
		end
	      else
		begin
		  zm_in_readyQ <= 1'b0;
		  zm_progress <= {8'h00, zm_cmd[3:0], 4'b0000};
		  zm_init_count <= zm_init_count + 1'b1;
		end	      
	    end
	  
	  ZM_RUN_C:
	    begin
	      // zuc core generates the keystream output, 32b/clock. 
	      // Accumulate the ciphered text into accum_reg,
	      // and once every 16 clocks, or until end_of_message:
	      // 1. Read next message line from fifo_in
	      // 2. Write accum_reg to fifo_out
	      
  // ZUC responses accumulation (32b -> 512b) and writing to fifo_out
  // While zm_core is busy, watch for its output to accumulate the zuc output into a line_sized accum_reg,
  // and once every 16 clocks, write this reg to fifo_out
  // 
  // zm_done zm_ks_valid count | Operation                    | Description
  // --------------------------+------------------------------+--------------------------------------------------------
  // 0       0           <15   | nothing                      | zuc_core is busy, but still did not output next 32b text
  // 0       0           >=15  | nothing                      | zuc_core is busy, but still did not output the last 32b text in a line
  // 0       1           <15   | count++, accum_reg<=text     | A new 32b text is valid, but still not accumulated a full line
  // 0       1           >=15  | count=0, fifo_out<=accum_reg | A full line is accumulated. Write to fifo_out, with keep=FULL_LINE, last=0
  // 1       0           <15   | nothing                      | zuc_core is idle
  // 1       0           >=15  | nothing                      | Invalid case. While zuc_core is idle count is cleared
  // 1       1           <15   | count=0, fifo_out<=accum_reg | End_of_message & partial line. Write to fifo_out, with keep=PARTIAL_LINE, last=1
  // 1       1           >=15  | count=0, fifo_out<=accum_reg | End_of_message & full line. Write to fifo_out, with keep=FULL_LINE, last=1
  //

	      zm_test_mode_text_in_valid <= 1'b0;
	      if (zm_message_size_inprogress == zm_in_message_csize)
		// End of C message:
		begin
		  if (zm_text_32b_index > 0)
		    // end_of_message & accume_reg not empty, write it to fifo_out
		    begin
		      zm_core_valid <= 1'b1;
		      zm_core_last <= zm_in_test_mode ? 1'b0 : 1'b1; // end_of_message only if not test_mode
		     // TBD: Replace 64'b1 count_to_keep(zm_text_32b_index):
		      zm_core_keep <= 64'hffffffffffffffff;
		    end
		  else
		    zm_core_valid <= 1'b0;
		  
		  zm_go <= 1'b0; // Stop zuc_core
		  zm_done <= 1'b1;
		  zm_in_readyQ <= 1'b0;
		  zm_progress <= {2'b00, (zm_text_32b_index == 0) ? 6'h10 : zm_text_32b_index, zm_cmd[3:0], 4'b0010}; // Report last flit
		  zm_response_status <= 4'h0; // OK status
		  zuc_module_nstate <= ZM_STATUS;
		end

	      else
		// C command still ongoing. Keep generating keystream words:
		begin
		  zm_message_size_inprogress <= zm_message_size_inprogress + 1'b1;
		  zm_in_message_bits <= zm_in_message_bits - 'd32; // Keeping track of remaining message bits to handle
		  zuc_module_nstate <= ZM_RUN_C;

		  if (zm_text_32b_index >= 15)
		    // End of a 512b line reached.
		    // 1. Read next message line from fifo_in
		    // 2. Write accu_reg to fifo_out
		    begin
		      zm_out_accum_reg[31:0] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[31:0];
		      zm_text_in_reg <= zm_in_data;
		      if (zm_in_message_csize - zm_message_size_inprogress > 1)
			begin
		      	  // Still far from end of message. Read next line from fifo_in
		          zm_in_readyQ <= 1'b1;
			  zm_progress <= {2'b00, zm_text_32b_index + 1, zm_cmd[3:0], 4'b0010};
			end
			
		      zm_text_32b_index <= 6'h00;

		      // write a full accum_reg to fifo_out
		      zm_core_valid <= 1'b1;
		      zm_core_keep <= FULL_LINE_KEEP;
		      if (zm_in_message_csize  == zm_message_size_inprogress + 1)
		      // final flit: end_of_message
		      zm_core_last <= zm_in_test_mode ? 1'b0 : 1'b1; // end_of_message only if not test_mode
 		    end
		  
		  else
		    begin
		      // Still within the message line:
		      // 1. drop latter 32b from text_in_reg
		      // 2. Accumulate zm_keystream into accum_reg

		      case (zm_text_32b_index)
			0:
			  begin
			    // To avoid partially garbaged zm_out_accum_reg, in case the last message line is not full,
			    // the upper part in zm_out_accum_reg is also cleared upon first keystream load:
			    zm_out_accum_reg[511:480] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[511:480];
			    zm_out_accum_reg[479:0] <= 480'b0;
			  end
			
			1:
			  begin
			    zm_out_accum_reg[479:448] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[479:448];
			  end
			
			2:
			  begin
			    zm_out_accum_reg[447:416] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[447:416];
			  end
			
			3:
			  begin
			    zm_out_accum_reg[415:384] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[415:384];
			  end

			4:
			  begin
			    zm_out_accum_reg[383:352] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[383:352];
			  end
			
			5:
			  begin
			    zm_out_accum_reg[351:320] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[351:320];
			  end
			
			6:
			  begin
			    zm_out_accum_reg[319:288] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[319:288];
			  end
			
			7:
			  begin
			    zm_out_accum_reg[287:256] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[287:256];
			  end

			8:
			  begin
			    zm_out_accum_reg[255:224] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[255:224];
			  end
			
			9:
			  begin
			    zm_out_accum_reg[223:192] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[223:192];
			  end
			
			10:
			  begin
			    zm_out_accum_reg[191:160] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[191:160];
			  end
			
			11:
			  begin
			    zm_out_accum_reg[159:128] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[159:128];
			  end

			12:
			  begin
			    zm_out_accum_reg[127:96] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[127:96];
			  end
			
			13:
			  begin
			    zm_out_accum_reg[95:64] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[95:64];
			  end
			
			14:
			  begin
			    zm_out_accum_reg[63:32] <= (zm_keystream & cipher_bytes) ^ zm_text_in_reg[63:32];
			  end
			
			15:
			  begin
			    // Last 32b is handled separately, along with writing accum_reg to zm_out_data
			  end
			
			default:
			  begin
			  end
		      endcase

		      zm_in_readyQ <= 1'b0;
		      zm_progress <= {8'h00, zm_cmd[3:0], 4'b0000};
		      zm_core_valid <= 1'b0;
		      zm_text_32b_index <= zm_text_32b_index + 1;
 		    end
		end
	    end
	  
	  ZM_WAIT_2KEYS:
	    begin
	      zm_test_mode_text_in_valid <= 1'b0;
	      zm_in_readyQ <= 1'b0;
	      zm_progress <= {8'h00, zm_cmd[3:0], 4'b0000};
	      zm_keystream96 <= {zm_keystream96[63:0], zm_keystream};
	      if (zm_wait_keystream > 1)
		  zm_wait_keystream <= zm_wait_keystream - 1'b1;
	      else
		begin
		  zuc_module_nstate <= ZM_RUN_I;
		end
	    end

	  ZM_RUN_I:
	    begin
	      // zuc core starts generating the keystream output, for MAC calc
	      // zuc core generates at least 3 keystream words, even for a 1b message length !!!
	      
 	      // Mac calculation starts once third keystream word is avialable: MAC calc requires latter two keystream words 
	      // TBD: Revisit this 3-clocks delay, to be reduced to two clocks
	      // Ongoing MAC calculation
	      
 	      // While watching for end of message, do:
	      // MAC calc iterations end at exactly the same as encrypt calc.
	      // ???????????Yet, following this phase, there are two more clac steps, carried out in states MAC1 and MAC2   
	      if (zm_message_size_inprogress == zm_in_message_csize - 1)
		// End of I message, but not the end of MAC calc !!
		// zuc_core is kept working for one more clock, to generate an extra 32b keystream
		begin
		  zm_in_readyQ <= 1'b0;
		  zm_progress <= {2'b00, zm_text_32b_index + 1, zm_cmd[3:0], 4'b0010}; // Report last flit
		  zm_mac_reg <= zm_mac_reg ^ zm_mac_0_31;
		  zm_keystream96_lastkey <= zm_keystream96 << zm_in_message_bits;

		  // module test mode & INTEG command: Write latter accumulated keystream words to fifo_out
		  zm_test_mode_keystream_valid <= 1'b1;
		  zuc_module_nstate <= ZM_MAC1;
		end
	      
	      else
		// I command still ongoing. Keep generating keystream words & MAC calculation:
		begin
		  zm_mac_reg <= zm_mac_reg ^ zm_mac_0_31;
		  zm_keystream96 <= {zm_keystream96[63:0], zm_keystream};
		  zm_message_size_inprogress <= zm_message_size_inprogress + 1'b1;
		  zm_in_message_bits <= zm_in_message_bits - 'd32; // Keeping track of remaining message bits to handle
		  
		  zuc_module_nstate <= ZM_RUN_I;
		  
		  if (zm_text_32b_index >= 15)
		    // end of a 512b line reached. Load next zm_in_data line from fifo_in
		    // Once every 16 clocks (zuc_in line_size/32b), load next fifo_in line to text_in_reg
		    begin
		      zm_in_readyQ <= 1'b1;
		      zm_progress <= {2'b00, zm_text_32b_index + 1, zm_cmd[3:0], 4'b0010};
		      zm_text_in_reg <= zm_in_data;
		      zm_text_32b_index <= 6'h00;
 		    end
		  
		  else
		    begin
		      zm_in_readyQ <= 1'b0;
		      zm_progress <= {8'h00, zm_cmd[3:0], 4'b0000};
		      zm_text_in_reg <= {zm_text_in_reg[479:0], 32'h00000000}; // 32b shift left
		      zm_text_32b_index <= zm_text_32b_index + 1;
 		    end
		end
	    end 
	  
	  ZM_MAC1:
	    begin
	      // zuc_core finished generating keystream words for MAC calc
	      // Here, last generated zm_keystream is loaded 

	      zm_go <= 1'b0; // Stop zuc_core
	      zm_progress <= {8'h00, zm_cmd[3:0], 4'b0000};
	      zm_test_mode_keystream_valid <= 1'b0;
	      zuc_module_nstate <= ZM_MAC2;
	    end
	      
	  ZM_MAC2:
	    begin
	      // MAC calculation
	      //// L = (LENGTH + 95) / 32;
	      ////   LENGTH - Message length in bits
	      ////   z      - Generated keystream
	      ////   L      - z length. Number of generated 32b keystream words
	      // Notice that z length is always greater than message length by 2 !!
	      // which means: at least 3 x 32b keystream is generated, even for a 1b message !!!
	      //
	      // MAC Iterations:
	      //// T = 0; 
	      //// for (i=0; i<LENGTH; i++) {
	      ////    if (GET_BIT(M,i)) {
	      ////       T ^= GET_WORD(z,i);
	      ////    }
	      ////}
	      //// MAC = T ^ z[L-2]) ^ z[L-1]; 

	      // Final MAC calculation: 
	      zm_mac_reg <= zm_mac_reg ^ zm_keystream96[31:0] ^ zm_keystream96_lastkey[95:64];

	      // Write MAC to fifo_out
	      // No need to check zuc_out_ready since we already guaranteed sufficient space in fifo_out
	      zm_done <= 1'b1;
	      zm_core_valid <= 1'b1;
	      zm_core_last <= 1'b1;
	      zm_core_keep <= 64'h000000000000000f;
	      zm_response_status <= 4'h0; // OK status
	      zuc_module_nstate <= ZM_STATUS;
	    end

	  ZM_BYPASS:
	    begin
	      // Bypass the incoming message from fifo_in to fifo_out
	      // fifo_out already verified to have sufficient space. No need to recheck fifo_out_ready
	      // Yet, we do need to check zm_in_message_valid, since we checked only the first line, and assumed the whole message will follow.
	      //
	      // Keep writing fifo_out and reading from fifo_in
	      // zm_bypass_or_header is kept asserted thru the whole bypass process
	      if (zm_in_message_valid)
		begin
		  zm_bypass_or_header_valid <= 1'b1;
		  
		  if (zm_in_last)
		    // TO end the bypass, we rely on EOM indication, rather than on *message_size, since the *size might not match the actual message size.

		    begin 
		      zm_in_readyQ <= 1'b0;
		      zm_bypass_or_header_valid <= 1'b0;
		      zm_progress <= {8'h00, zm_cmd[3:0], 4'b0001}; // Report last flit bypass, and end of message bypass
		      zuc_module_nstate <= ZM_STATUS;
		    end
		  else
		    begin
		      // Keep reading until end of message
		      zm_in_readyQ <= 1'b1;
		      zm_in_message_size <= zm_in_message_size - FIFO_LINE_SIZE;
		      zm_progress <= {8'h00, zm_cmd[3:0], 4'b0010};  // Report another flit bypass
		    end
		end
	      
	      else
		// wait for next fifo_in line 
		begin
		  zm_in_readyQ <= 1'b0;
		  zm_progress <= {8'h00, zm_cmd[3:0], 4'b0000};
		  zm_bypass_or_header_valid <= 1'b0;
		end
	    end
	  
	  ZM_STATUS:
	    begin
	      // This state is visited at end of both INTEG abd CONF commands.
	      // Here, *keystream_valid is activated only at CONF command.
	      if (zm_cmd == MESSAGE_CMD_CONF)
		begin
		  zm_test_mode_keystream_valid <= 1'b1;
		  zm_core_last <= 1'b1;
		end
	      
	      // Write C/I operation status. Wait if status fifo not ready
	      zm_core_valid <= 1'b0;
	      zm_bypass_or_header_valid <= 1'b0;
	      zm_progress <= {8'h00, zm_cmd[3:0], 4'b0000};
	      if (zm_out_status_ready)
		begin
		  zm_out_status_data <= {zm_channel_id[3:0], zm_response_status[3:0]}; // TBD: update status...
		  zm_out_status_valid <= 1'b1;
		  zm_update_module_regsQ <= 1'b1; // update zuc module message_count
		  zuc_module_nstate <= ZM_END;
		end
	    end

	  ZM_END:
	    begin
	      zm_test_mode_keystream_valid <= 1'b0;
	      zm_core_last <= 1'b0;
	      zm_in_readyQ <= 1'b0;
	      zm_progress <= {8'h00, zm_cmd[3:0], 4'b0000};
	      zm_out_status_valid <= 1'b0;
	      zm_go <= 1'b0;
	      zm_done <= 1'b0;
	      zm_update_module_regsQ <= 1'b0; // update zuc module message_count
	      zm_bypass_or_header <= 1'b0;
	      zm_wait_keystream <= 2'b10;
	      zuc_module_nstate <= ZM_IDLE;
	    end
	  
	  default:
	    begin
	    end
	endcase
      end
  end
  
// zuc module output stats
  always @(posedge zm_clk) begin
    if (zm_reset) begin
      zm_core_util <=  64'h0000000000000000;
      zm_core_elapsed_time <= 64'h0000000000000001; // To avoid DIVZ after reset
      zm_core_busy_time <= 48'h000000000000;
      zm_out_stats <= 32'h00000000;
      zm_clc_freq <= ZUC_AFU_FREQ << 20;  // clock freq (hz)
    end
    else
      begin
	zm_core_elapsed_time <= zm_core_elapsed_time + 1;
	if (zuc_module_nstate != ZM_IDLE)
	  zm_core_busy_time <= zm_core_busy_time + 1;
	
	zm_core_util <= (zm_core_busy_time << 16) / zm_core_elapsed_time;
	zm_out_stats <= {zm_core_util[15:0], 12'h000, zuc_module_nstate};
      end
  end


// Module test mode: Accumulating keystream words into a 512b flit:
  reg [4:0] 	zm_test_mode_keystream_count;
  reg 		zm_keystream_validQ;

  always @(posedge zm_clk) begin
    if (zm_reset || (zuc_module_nstate == ZM_IDLE)) begin
      zm_test_mode_keystream <= 512'b0;
      zm_test_mode_keystream_count <= 5'h0f;
      zm_keystreamQ <= 32'b0;
      zm_keystream_validQ <= 1'b0;
    end
    else
      begin
	// Keystreams are continuously accumulated, while main SM is not idle
	// Accumulation direction: from MSB to LSB (first keystream to [511:480] ...)
	// Once every 16 iterations, the register is cleared, to assure loading next keystreams into a clean register
	// The register *_valid signal is controlled by main SM
	zm_keystreamQ <= zm_keystream;
	zm_keystream_validQ <= zm_keystream_valid;

	if (zm_keystream_validQ && ~zm_done)
	  zm_test_mode_keystream <= {zm_test_mode_keystream[480:0], zm_keystreamQ};
      end
  end

  
  // zuc_core output text aggregation/MAC calc logic:
  // 
  
  // ???? Verify that zm_out_accum_reg[31:0] (last 32b in a line) is valid at the time of write to fifo_out
  //
  // Bypass cmd: Selecting between bypassed data and zuc_core output
  assign zm_bypass_keep = (zm_in_message_size >= FIFO_LINE_SIZE) ? 
			  // TBD: Replace 64'b1 with count_to_keep(zm_in_message_size[5:0]): 
			  FULL_LINE_KEEP : 64'b1; 
  
  assign zm_out_data = (zm_bypass_or_header || zm_test_mode_text_in_valid)
		       ?
		         zm_in_data
		       :                                              // Bypass mode
		         zm_test_mode_data_valid
		         ?
		           zm_test_mode_data                          // at module test_mode, lfsr dumped to fifo_out
		         :
		           (zm_done && (zm_cmd == MESSAGE_CMD_INTEG))
			   ?
		           // INTEG response[416:160] should be cleared when writen to sbu2pci_data.
		           // but in bypass or test_mode, this fild holds the origigal IV & Key.
		           // INTEG response[59:0] should be cleared when writen to sbu2pci_data.
		           // but until then, we use this field to transfer some medatata, used for message_id ordering
		           // See "Internal AFU Message Header" in zuc_afu.v for details. 
		           // Corresponding scu2pci_keep bits will be cleared anyway
 		             {zm_in_header[511:160], zm_mac_reg, 68'b0, zm_in_header[59:0]}
		           :
		             zm_out_accum_reg;                                     // CONF response
 
  assign zm_test_mode_data_valid = zm_in_test_mode ?
				   (zm_test_mode_lfsr_valid || zm_test_mode_keystream_valid) :
				   1'b0;
  assign zm_test_mode_data = zm_test_mode_lfsr_valid ? zm_test_mode_lfsr :
			     zm_test_mode_keystream;

  assign zm_out_keep = zm_bypass_or_header ? zm_bypass_keep : zm_core_keep;
  assign zm_out_last = zm_bypass_or_header ? zm_in_last : zm_core_last;
  assign zm_out_valid = zm_bypass_or_header ? zm_bypass_or_header_valid : (zm_core_valid || zm_test_mode_data_valid || zm_test_mode_text_in_valid);
  assign zm_in_ready = zm_in_readyQ;
  

  always @(*) begin
    // MAC bytemask, to support byte rolution
    if (zm_in_message_bits > 'd24)
      begin
	mac_bytes <= 4'b1111;
	cipher_bytes <= zm_in_force_corebypass ? 32'h00000000 : 32'hffffffff;
      end
    else if (zm_in_message_bits > 'd16)
      begin
	mac_bytes <= 4'b1110;
	cipher_bytes <= zm_in_force_corebypass ? 32'h00000000 : 32'hffffff00;
      end
    else if (zm_in_message_bits > 'd8)
      begin
	mac_bytes <= 4'b1100;
	cipher_bytes <= zm_in_force_corebypass ? 32'h00000000 : 32'hffff0000;
      end
    else if (zm_in_message_bits > 0)
      begin
	mac_bytes <= 4'b1000;
	cipher_bytes <= zm_in_force_corebypass ? 32'h00000000 : 32'hff000000;
      end
    else
      begin
	mac_bytes <= 4'b0000;
	cipher_bytes <= zm_in_force_corebypass ? 32'h00000000 : 32'hffffffff;
      end
  end
  

  // MAC logic:
  always @(*) begin
    zm_mac0  = zm_text_in_reg[511] && mac_bytes[3] ? zm_keystream96[95:64] : 32'h00000000;
    zm_mac1  = zm_text_in_reg[510] && mac_bytes[3] ? zm_keystream96[94:63] : 32'h00000000;
    zm_mac2  = zm_text_in_reg[509] && mac_bytes[3] ? zm_keystream96[93:62] : 32'h00000000;
    zm_mac3  = zm_text_in_reg[508] && mac_bytes[3] ? zm_keystream96[92:61] : 32'h00000000;
    zm_mac4  = zm_text_in_reg[507] && mac_bytes[3] ? zm_keystream96[91:60] : 32'h00000000;
    zm_mac5  = zm_text_in_reg[506] && mac_bytes[3] ? zm_keystream96[90:59] : 32'h00000000;
    zm_mac6  = zm_text_in_reg[505] && mac_bytes[3] ? zm_keystream96[89:58] : 32'h00000000;
    zm_mac7  = zm_text_in_reg[504] && mac_bytes[3] ? zm_keystream96[88:57] : 32'h00000000;
    zm_mac8  = zm_text_in_reg[503] && mac_bytes[2] ? zm_keystream96[87:56] : 32'h00000000;
    zm_mac9  = zm_text_in_reg[502] && mac_bytes[2] ? zm_keystream96[86:55] : 32'h00000000;
    zm_mac10 = zm_text_in_reg[501] && mac_bytes[2] ? zm_keystream96[85:54] : 32'h00000000;
    zm_mac11 = zm_text_in_reg[500] && mac_bytes[2] ? zm_keystream96[84:53] : 32'h00000000;
    zm_mac12 = zm_text_in_reg[499] && mac_bytes[2] ? zm_keystream96[83:52] : 32'h00000000;
    zm_mac13 = zm_text_in_reg[498] && mac_bytes[2] ? zm_keystream96[82:51] : 32'h00000000;
    zm_mac14 = zm_text_in_reg[497] && mac_bytes[2] ? zm_keystream96[81:50] : 32'h00000000;
    zm_mac15 = zm_text_in_reg[496] && mac_bytes[2] ? zm_keystream96[80:49] : 32'h00000000;
    zm_mac16 = zm_text_in_reg[495] && mac_bytes[1] ? zm_keystream96[79:48] : 32'h00000000;
    zm_mac17 = zm_text_in_reg[494] && mac_bytes[1] ? zm_keystream96[78:47] : 32'h00000000;
    zm_mac18 = zm_text_in_reg[493] && mac_bytes[1] ? zm_keystream96[77:46] : 32'h00000000;
    zm_mac19 = zm_text_in_reg[492] && mac_bytes[1] ? zm_keystream96[76:45] : 32'h00000000;
    zm_mac20 = zm_text_in_reg[491] && mac_bytes[1] ? zm_keystream96[75:44] : 32'h00000000;
    zm_mac21 = zm_text_in_reg[490] && mac_bytes[1] ? zm_keystream96[74:43] : 32'h00000000;
    zm_mac22 = zm_text_in_reg[489] && mac_bytes[1] ? zm_keystream96[73:42] : 32'h00000000;
    zm_mac23 = zm_text_in_reg[488] && mac_bytes[1] ? zm_keystream96[72:41] : 32'h00000000;
    zm_mac24 = zm_text_in_reg[487] && mac_bytes[0] ? zm_keystream96[71:40] : 32'h00000000;
    zm_mac25 = zm_text_in_reg[486] && mac_bytes[0] ? zm_keystream96[70:39] : 32'h00000000;
    zm_mac26 = zm_text_in_reg[485] && mac_bytes[0] ? zm_keystream96[69:38] : 32'h00000000;
    zm_mac27 = zm_text_in_reg[484] && mac_bytes[0] ? zm_keystream96[68:37] : 32'h00000000;
    zm_mac28 = zm_text_in_reg[483] && mac_bytes[0] ? zm_keystream96[67:36] : 32'h00000000;
    zm_mac29 = zm_text_in_reg[482] && mac_bytes[0] ? zm_keystream96[66:35] : 32'h00000000;
    zm_mac30 = zm_text_in_reg[481] && mac_bytes[0] ? zm_keystream96[65:34] : 32'h00000000;
    zm_mac31 = zm_text_in_reg[480] && mac_bytes[0] ? zm_keystream96[64:33] : 32'h00000000;
    
    zm_mac_0_7   = zm_mac0  ^ zm_mac1  ^ zm_mac2  ^ zm_mac3  ^ zm_mac4  ^ zm_mac5  ^ zm_mac6  ^ zm_mac7;
    zm_mac_8_15  = zm_mac8  ^ zm_mac9  ^ zm_mac10 ^ zm_mac11 ^ zm_mac12 ^ zm_mac13 ^ zm_mac14 ^ zm_mac15;
    zm_mac_16_23 = zm_mac16 ^ zm_mac17 ^ zm_mac18 ^ zm_mac19 ^ zm_mac20 ^ zm_mac21 ^ zm_mac22 ^ zm_mac23;
    zm_mac_24_31 = zm_mac24 ^ zm_mac25 ^ zm_mac26 ^ zm_mac27 ^ zm_mac28 ^ zm_mac29 ^ zm_mac30 ^ zm_mac31;
    zm_mac_0_31  = zm_mac_0_7 ^ zm_mac_8_15 ^ zm_mac_16_23 ^ zm_mac_24_31;
  end  


  // ZUC Core:
  // zuc_module (zm_*) to/from zuc_core (zc_*) interface signals:
  zuc_core zuc_core (
		     .zc_clk(zm_clk),
		     .zc_reset(zm_reset),
		     .zc_iv(zm_iv),
		     .zc_key(zm_key),
		     .zc_cmd(zm_cmd),
		     .zc_go(zm_go),
		     .zc_lfsr(zm_test_mode_lfsr),
		     .zc_lfsr_valid(zm_test_mode_lfsr_valid),
		     .zc_keystream(zm_keystream),
		     .zc_keystream_valid(zm_keystream_valid)
		     );
endmodule
