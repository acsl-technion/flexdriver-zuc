// zuc core
//
//

module zuc_core (
  input wire 	      zc_clk,
  input wire 	      zc_reset,
  input wire [127:0]  zc_iv,
  input wire [127:0]  zc_key,
  input wire [7:0]    zc_cmd,
  input wire 	      zc_go, // Asserted after IK, IV are ready. Dropped after end of message input
  output wire [511:0] zc_lfsr,
  output reg 	      zc_lfsr_valid,
  output reg [31:0]   zc_keystream,
  output reg 	      zc_keystream_valid
  );

  localparam [7:0]
    ZC_CMD_CONF      = 8'h00,
    ZC_CMD_INTEG     = 8'h01;

  localparam [2:0]
    ZUC_CORE_IDLE       = 3'b000,
    ZUC_CORE_INIT       = 3'b001,
    ZUC_CORE_LFSRINIT   = 3'b010,
    ZUC_CORE_LFSRWORK   = 3'b011,
    ZUC_CORE_END        = 3'b100;

  reg [31:0] 	      lfsr_s0,lfsr_s1,lfsr_s2,lfsr_s3,lfsr_s4,lfsr_s5,lfsr_s6,lfsr_s7, 
		      lfsr_s8,lfsr_s9,lfsr_s10,lfsr_s11,lfsr_s12,lfsr_s13,lfsr_s14,lfsr_s15;
  reg [3:0] 	      zc_nstate;
  reg 		      zc_init;
  reg 		      zc_lfsrwithinit;
//  reg 		      zc_lfsr_valid;
  
// iv & key elements
// zuc_iv* and zuc_key* bytes are swapped, based on Haggai's request (12-Nov-2020:
// "Reversing in software requires additional CPU cycles. The existing code in DPDK and its applications uses a certain order with the existing API. If we want to reverse in software it means reversing the values that are passed to the driver. For the key we could do it once and save the result, but the IV is passed on every so it would waste cycles for every crypto operation"
  
//  wire [7:0] 	      zuc_iv0  = zc_iv[  7:  0];
//  wire [7:0] 	      zuc_iv1  = zc_iv[ 15:  8];
//  wire [7:0] 	      zuc_iv2  = zc_iv[ 23: 16];
//  wire [7:0] 	      zuc_iv3  = zc_iv[ 31: 24];
//  wire [7:0] 	      zuc_iv4  = zc_iv[ 39: 32];
//  wire [7:0] 	      zuc_iv5  = zc_iv[ 47: 40];
//  wire [7:0] 	      zuc_iv6  = zc_iv[ 55: 48];
//  wire [7:0] 	      zuc_iv7  = zc_iv[ 63: 56];
//  wire [7:0] 	      zuc_iv8  = zc_iv[ 71: 64];
//  wire [7:0] 	      zuc_iv9  = zc_iv[ 79: 72];
//  wire [7:0] 	      zuc_iv10 = zc_iv[ 87: 80];
//  wire [7:0] 	      zuc_iv11 = zc_iv[ 95: 88];
//  wire [7:0] 	      zuc_iv12 = zc_iv[103: 96];
//  wire [7:0] 	      zuc_iv13 = zc_iv[111:104];
//  wire [7:0] 	      zuc_iv14 = zc_iv[119:112];
//  wire [7:0] 	      zuc_iv15 = zc_iv[127:120];

  wire [7:0] 	      zuc_iv15 = zc_iv[  7:  0];
  wire [7:0] 	      zuc_iv14 = zc_iv[ 15:  8];
  wire [7:0] 	      zuc_iv13 = zc_iv[ 23: 16];
  wire [7:0] 	      zuc_iv12 = zc_iv[ 31: 24];
  wire [7:0] 	      zuc_iv11 = zc_iv[ 39: 32];
  wire [7:0] 	      zuc_iv10 = zc_iv[ 47: 40];
  wire [7:0] 	      zuc_iv9  = zc_iv[ 55: 48];
  wire [7:0] 	      zuc_iv8  = zc_iv[ 63: 56];
  wire [7:0] 	      zuc_iv7  = zc_iv[ 71: 64];
  wire [7:0] 	      zuc_iv6  = zc_iv[ 79: 72];
  wire [7:0] 	      zuc_iv5  = zc_iv[ 87: 80];
  wire [7:0] 	      zuc_iv4  = zc_iv[ 95: 88];
  wire [7:0] 	      zuc_iv3  = zc_iv[103: 96];
  wire [7:0] 	      zuc_iv2  = zc_iv[111:104];
  wire [7:0] 	      zuc_iv1  = zc_iv[119:112];
  wire [7:0] 	      zuc_iv0  = zc_iv[127:120];

//  wire [7:0] 	      zuc_k0  = zc_key[  7:  0];
//  wire [7:0] 	      zuc_k1  = zc_key[ 15:  8];
//  wire [7:0] 	      zuc_k2  = zc_key[ 23: 16];
//  wire [7:0] 	      zuc_k3  = zc_key[ 31: 24];
//  wire [7:0] 	      zuc_k4  = zc_key[ 39: 32];
//  wire [7:0] 	      zuc_k5  = zc_key[ 47: 40];
//  wire [7:0] 	      zuc_k6  = zc_key[ 55: 48];
//  wire [7:0] 	      zuc_k7  = zc_key[ 63: 56];
//  wire [7:0] 	      zuc_k8  = zc_key[ 71: 64];
//  wire [7:0] 	      zuc_k9  = zc_key[ 79: 72];
//  wire [7:0] 	      zuc_k10 = zc_key[ 87: 80];
//  wire [7:0] 	      zuc_k11 = zc_key[ 95: 88];
//  wire [7:0] 	      zuc_k12 = zc_key[103: 96];
//  wire [7:0] 	      zuc_k13 = zc_key[111:104];
//  wire [7:0] 	      zuc_k14 = zc_key[119:112];
//  wire [7:0] 	      zuc_k15 = zc_key[127:120];
  wire [7:0] 	      zuc_k15  = zc_key[  7:  0];
  wire [7:0] 	      zuc_k14  = zc_key[ 15:  8];
  wire [7:0] 	      zuc_k13  = zc_key[ 23: 16];
  wire [7:0] 	      zuc_k12  = zc_key[ 31: 24];
  wire [7:0] 	      zuc_k11  = zc_key[ 39: 32];
  wire [7:0] 	      zuc_k10  = zc_key[ 47: 40];
  wire [7:0] 	      zuc_k9   = zc_key[ 55: 48];
  wire [7:0] 	      zuc_k8   = zc_key[ 63: 56];
  wire [7:0] 	      zuc_k7   = zc_key[ 71: 64];
  wire [7:0] 	      zuc_k6   = zc_key[ 79: 72];
  wire [7:0] 	      zuc_k5   = zc_key[ 87: 80];
  wire [7:0] 	      zuc_k4   = zc_key[ 95: 88];
  wire [7:0] 	      zuc_k3   = zc_key[103: 96];
  wire [7:0] 	      zuc_k2   = zc_key[111:104];
  wire [7:0] 	      zuc_k1   = zc_key[119:112];
  wire [7:0] 	      zuc_k0   = zc_key[127:120];

  reg 		      zc_goQ, zc_request;
  wire 		      zuc_req_validD;
  reg [5:0] 	      zc_lfsrinit_count;

  wire [31:0] br_x0, br_x1, br_x2, br_x3;
  wire [31:0] f_w_cond;

  reg [31:0] f_w, f_r1, f_r2;
  reg [31:0] f_w1, f_w2, f_u, f_ua, f_v, f_va, f_r1_D, f_r2_D;
  reg [7:0]  zuc_s00_in, zuc_s01_in, zuc_s02_in, zuc_s03_in, zuc_s10_in, zuc_s11_in, zuc_s12_in, zuc_s13_in;
  wire [7:0]  zuc_s00_out, zuc_s01_out, zuc_s02_out, zuc_s03_out, zuc_s10_out, zuc_s11_out, zuc_s12_out, zuc_s13_out;

  wire [31:0] lfsr_s15p15, lfsr_s13p17, lfsr_s10p21, lfsr_s4p20, lfsr_s0p8;
  wire [35:0] lfsr_s16_sum, lfsr_s16_carry;
  reg [35:0]  lfsr_s16_sc1;
  reg [31:0]  lfsr_s16_sc2;
  reg [4:0]   lfsr_s16_msb;
  reg [31:0]  lfsr_s16;

  wire [31:0] lfsr_sum;
  wire [31:0] lfsr_carry;
  wire [31:0] lfsr_w_cond;


//D Constants
  localparam
    zuc_d0 =  16'h44D7,
    zuc_d1 =  16'h26BC,
    zuc_d2 =  16'h626B,
    zuc_d3 =  16'h135E,
    zuc_d4 =  16'h5789,
    zuc_d5 =  16'h35E2,
    zuc_d6 =  16'h7135,
    zuc_d7 =  16'h09AF,
    zuc_d8 =  16'h4D78,
    zuc_d9 =  16'h2F13,
    zuc_d10 = 16'h6BC4,
    zuc_d11 = 16'h1AF1,
    zuc_d12 = 16'h5E26,
    zuc_d13 = 16'h3C4D,
    zuc_d14 = 16'h789A,
    zuc_d15 = 16'h47AC;


  always @(posedge zc_clk) begin
    if (zc_reset) begin
      zc_request <= 1'b0;
//      zc_lfsrinit_count <= 6'd33;
    end
    else begin
      zc_goQ <= zc_go;
      if (~zc_goQ && zc_go && (zc_cmd == ZC_CMD_CONF) || (zc_cmd == ZC_CMD_INTEG))
	// Start a zuc init&work flow only if valid cmd
	zc_request <= 1'b1;
      else if (zc_goQ && ~zc_go)
	zc_request <= 1'b0;
    end	
  end
  
  assign zc_lfsr = {lfsr_s0,lfsr_s1, lfsr_s2, lfsr_s3, lfsr_s4, lfsr_s5, lfsr_s6, lfsr_s7, 
		    lfsr_s8,lfsr_s9,lfsr_s10,lfsr_s11,lfsr_s12,lfsr_s13,lfsr_s14,lfsr_s15};

  
  // zuc_core ctrl:
  always @(posedge zc_clk) begin
    if (zc_reset) begin
      lfsr_s0 <= 32'h00000000;
      lfsr_s1 <= 32'h00000000;
      lfsr_s2 <= 32'h00000000;
      lfsr_s3 <= 32'h00000000;
      lfsr_s4 <= 32'h00000000;
      lfsr_s5 <= 32'h00000000;
      lfsr_s6 <= 32'h00000000;
      lfsr_s7 <= 32'h00000000;
      lfsr_s8 <= 32'h00000000;
      lfsr_s9 <= 32'h00000000;
      lfsr_s10 <= 32'h00000000;
      lfsr_s11 <= 32'h00000000;
      lfsr_s12 <= 32'h00000000;
      lfsr_s13 <= 32'h00000000;
      lfsr_s14 <= 32'h00000000;
      lfsr_s15 <= 32'h00000000;

      zc_nstate <= ZUC_CORE_IDLE;
      zc_keystream_valid <= 1'b0;
      zc_init <= 1'b0;
      zc_lfsrwithinit <= 1'b1; // Default to LFSRWithInitMode
      zc_lfsr_valid <= 1'b0;
      
    end

    else begin
      case (zc_nstate)
	ZUC_CORE_IDLE:
	  begin
	    if (zc_go) begin
	      zc_init <= 1'b1;
	      zc_nstate <= ZUC_CORE_INIT;
	    end
	  end

	ZUC_CORE_INIT:
	  // A new ZUC command is present. Start with initializing LFSR
	  begin
	    // #define MAKEU31(a, b, c) (((u32)(a) << 23) | ((u32)(b) << 8) | (u32)(c))
	    //void Initialization(u8* k, u8* iv)
	    //{
	    //u32 w, nCount;
	    //* expand key */
	    //LFSR_Si = MAKEU31(k[i], EK_d[i], iv[i]);
	    //}
	    lfsr_s0  <= {1'b0, zuc_k0, 23'b0} | {8'b0, zuc_d0, 8'b0} | {24'b0, zuc_iv0};
	    lfsr_s1  <= {1'b0, zuc_k1, 23'b0} | {8'b0, zuc_d1, 8'b0} | {24'b0, zuc_iv1};
	    lfsr_s2  <= {1'b0, zuc_k2, 23'b0} | {8'b0, zuc_d2, 8'b0} | {24'b0, zuc_iv2};
	    lfsr_s3  <= {1'b0, zuc_k3, 23'b0} | {8'b0, zuc_d3, 8'b0} | {24'b0, zuc_iv3};
	    lfsr_s4  <= {1'b0, zuc_k4, 23'b0} | {8'b0, zuc_d4, 8'b0} | {24'b0, zuc_iv4};
	    lfsr_s5  <= {1'b0, zuc_k5, 23'b0} | {8'b0, zuc_d5, 8'b0} | {24'b0, zuc_iv5};
	    lfsr_s6  <= {1'b0, zuc_k6, 23'b0} | {8'b0, zuc_d6, 8'b0} | {24'b0, zuc_iv6};
	    lfsr_s7  <= {1'b0, zuc_k7, 23'b0} | {8'b0, zuc_d7, 8'b0} | {24'b0, zuc_iv7};
	    lfsr_s8  <= {1'b0, zuc_k8, 23'b0} | {8'b0, zuc_d8, 8'b0} | {24'b0, zuc_iv8};
	    lfsr_s9  <= {1'b0, zuc_k9, 23'b0} | {8'b0, zuc_d9, 8'b0} | {24'b0, zuc_iv9};
	    lfsr_s10  <= {1'b0, zuc_k10, 23'b0} | {8'b0, zuc_d10, 8'b0} | {24'b0, zuc_iv10};
	    lfsr_s11  <= {1'b0, zuc_k11, 23'b0} | {8'b0, zuc_d11, 8'b0} | {24'b0, zuc_iv11};
	    lfsr_s12  <= {1'b0, zuc_k12, 23'b0} | {8'b0, zuc_d12, 8'b0} | {24'b0, zuc_iv12};
	    lfsr_s13  <= {1'b0, zuc_k13, 23'b0} | {8'b0, zuc_d13, 8'b0} | {24'b0, zuc_iv13};
	    lfsr_s14  <= {1'b0, zuc_k14, 23'b0} | {8'b0, zuc_d14, 8'b0} | {24'b0, zuc_iv14};
	    lfsr_s15  <= {1'b0, zuc_k15, 23'b0} | {8'b0, zuc_d15, 8'b0} | {24'b0, zuc_iv15};
	    zc_lfsr_valid <= 1'b1;
	    zc_lfsrinit_count <= 6'd32; // 32 init iterations + 1 prework iteration
	    zc_init <= 1'b0;
	    zc_lfsrwithinit <= 1'b1;
	    zc_nstate <= ZUC_CORE_LFSRINIT;
	  end

	ZUC_CORE_LFSRINIT:
	  begin
	    lfsr_s0  <= lfsr_s1;
	    lfsr_s1  <= lfsr_s2;
	    lfsr_s2  <= lfsr_s3;
	    lfsr_s3  <= lfsr_s4;
	    lfsr_s4  <= lfsr_s5;
	    lfsr_s5  <= lfsr_s6;
	    lfsr_s6  <= lfsr_s7;
	    lfsr_s7  <= lfsr_s8;
	    lfsr_s8  <= lfsr_s9;
	    lfsr_s9  <= lfsr_s10;
	    lfsr_s10 <= lfsr_s11;
	    lfsr_s11 <= lfsr_s12;
	    lfsr_s12 <= lfsr_s13;
	    lfsr_s13 <= lfsr_s14;
	    lfsr_s14 <= lfsr_s15;
	    if (lfsr_s16 == 0)
	      lfsr_s15 <= 32'h7fffffff;
	    else
	      lfsr_s15 <= lfsr_s16;

	    if (zc_lfsrinit_count > 0)
	      begin
		if (zc_lfsrinit_count == 1)
		  begin
		    // The 33th iteration: f_w should be ignored
		    zc_lfsrwithinit <= 1'b0;
		    
		    // Module test mode: Almost_end of LFSR init. Sample lfsr to fifo_out
		    zc_lfsr_valid <= 1'b1;
		  end
		else
		  zc_lfsr_valid <= 1'b0;


		zc_lfsrinit_count <= zc_lfsrinit_count - 1;
		zc_nstate <= ZUC_CORE_LFSRINIT;
	      end
	    else
	      begin
		zc_lfsr_valid <= 1'b0;
		zc_nstate <= ZUC_CORE_LFSRWORK;
	      end
	  end

	ZUC_CORE_LFSRWORK:
	  begin
	    zc_lfsr_valid <= 1'b0;
	    lfsr_s0  <= lfsr_s1;
	    lfsr_s1  <= lfsr_s2;
	    lfsr_s2  <= lfsr_s3;
	    lfsr_s3  <= lfsr_s4;
	    lfsr_s4  <= lfsr_s5;
	    lfsr_s5  <= lfsr_s6;
	    lfsr_s6  <= lfsr_s7;
	    lfsr_s7  <= lfsr_s8;
	    lfsr_s8  <= lfsr_s9;
	    lfsr_s9  <= lfsr_s10;
	    lfsr_s10 <= lfsr_s11;
	    lfsr_s11 <= lfsr_s12;
	    lfsr_s12 <= lfsr_s13;
	    lfsr_s13 <= lfsr_s14;
	    lfsr_s14 <= lfsr_s15;
	    if (lfsr_s16 == 0)
	      lfsr_s15 <= 32'h7fffffff;
	    else
	      lfsr_s15 <= lfsr_s16;

	    if (zc_go)
	      zc_keystream_valid <= 1'b1;
	    else
	      begin
		zc_keystream_valid <= 1'b0;
		zc_nstate <= ZUC_CORE_END;
	      end
	  end

	ZUC_CORE_END:
	  begin
	    zc_lfsr_valid <= 1'b0;
	    zc_nstate <= ZUC_CORE_IDLE;
	  end

	default:
	  begin
	  end
      endcase




    end // else: !if(zc_reset)
  end

  
  
// Bit Reorganization:
//void BR(unsigned int LFSR_S[], unsigned int BR_X[])
//{
// 	BR_X[0] = ((LFSR_S[15] & 0x7fff8000) << 1) | (LFSR_S[14] & 0x0000ffff);
//        BR_X[1] = ((LFSR_S[11] & 0x0000ffff) << 16) | ((LFSR_S[9] & 0x7fff8000) >> 15);
//        BR_X[2] = ((LFSR_S[7] & 0x0000ffff) << 16) | ((LFSR_S[5] & 0x7fff8000) >> 15);
//        BR_X[3] = ((LFSR_S[2] & 0x0000ffff) << 16) | ((LFSR_S[0] & 0x7fff8000) >> 15);
//}
//
//* BitReorganization */
//void BitReorganization()
//{
//BRC_X0 = ((LFSR_S15 & 0x7FFF8000) << 1) | (LFSR_S14 & 0xFFFF);
//BRC_X1 = ((LFSR_S11 & 0xFFFF) << 16) | (LFSR_S9 >> 15);
//BRC_X2 = ((LFSR_S7 & 0xFFFF) << 16) | (LFSR_S5 >> 15);
//BRC_X3 = ((LFSR_S2 & 0xFFFF) << 16) | (LFSR_S0 >> 15);
//}

// assign br_x0 = ((lfsr_s15 & 32'h7FFF8000) <<  1) | (lfsr_s14  & 32'h0000FFFF);
// assign br_x1 = ((lfsr_s11 & 32'h0000FFFF) << 16) | (lfsr_s9  >> 15);
// assign br_x2 = ((lfsr_s7  & 32'h0000FFFF) << 16) | (lfsr_s5  >> 15);
// assign br_x3 = ((lfsr_s2  & 32'h0000FFFF) << 16) | (lfsr_s0  >> 15);
  assign br_x0 = {lfsr_s15[30:15], lfsr_s14[15:0]};
  assign br_x1 = {lfsr_s11[15:0],  lfsr_s9[30:15]};
  assign br_x2 = {lfsr_s7[15:0],   lfsr_s5[30:15]};
  assign br_x3 = {lfsr_s2[15:0],   lfsr_s0[30:15]};


// ZUC L1/L2 Functions
//#define ROT(a, k) (((a) << k) | ((a) >> (32 - k)))
//  function rotl;
//    input ina, inb;
//    begin
//      rotl = (ina << inb) | (ina >> (32 - inb));
//    end
//  endfunction // rotl

//u32 L1(u32 X)
//{
//return (X ^ ROT(X, 2) ^ ROT(X, 10) ^ ROT(X, 18) ^ ROT(X, 24));
//}
//  function zuc_l1;
//    input ina;
//    begin
//      zuc_l1 = ina ^ rotl(ina, 2) ^ rotl(ina, 10) ^ rotl(ina, 18) ^ rotl(ina, 24);
//    end
//  endfunction // zuc_l1
//
//u32 L2(u32 X)
//{
//return (X ^ ROT(X, 8) ^ ROT(X, 14) ^ ROT(X, 22) ^ ROT(X, 30));
//}
//  function zuc_l2;
//    input ina;
//    begin
//      zuc_l2 = ina ^ rotl(ina, 8) ^ rotl(ina, 14) ^ rotl(ina, 22) ^ rotl(ina, 30);
//    end
//  endfunction // zuc_l2
  
// ZUC F nonlinear function
//u32 F()
//{
//u32 W, W1, W2, u, v;
//W = (BRC_X0 ^ F_R1) + F_R2;
//W1 = F_R1 + BRC_X1;
//W2 = F_R2 ^ BRC_X2;
//u = L1((W1 << 16) | (W2 >> 16));
//v = L2((W2 << 16) | (W1 >> 16));
//F_R1 = MAKEU32(S0[u >> 24], S1[(u >> 16) & 0xFF],
//S0[(u >> 8) & 0xFF], S1[u & 0xFF]);
//F_R2 = MAKEU32(S0[v >> 24], S1[(v >> 16) & 0xFF],
//S0[(v >> 8) & 0xFF], S1[v & 0xFF]);
//return W;
//}
//
//	
//unsigned int F(unsigned int BR_X[], unsigned int F_R[])
//{
//        unsigned int W, W1, W2;
//
//	W = (BR_X[0] ^ F_R[0]) + F_R[1];
//      W1 = F_R[0] + BR_X[1];
//	W2 = F_R[1] ^ BR_X[2];
//      F_R[0] = L1((W1 << 16) | (W2 >> 16));
//	F_R[0] = (ZUC_S0[(F_R[0] >> 24) & 0xFF]) << 24 | (ZUC_S1[(F_R[0] >> 16) & 0xFF]) << 16 | (ZUC_S0[(F_R[0] >> 8) & 0xFF]) << 8 | (ZUC_S1[F_R[0] & 0xFF]);
//      F_R[1] = L2((W2 << 16) | (W1 >> 16));
//      F_R[1] = (ZUC_S0[(F_R[1] >> 24) & 0xFF]) << 24 | (ZUC_S1[(F_R[1] >> 16) & 0xFF]) << 16 | (ZUC_S0[(F_R[1] >> 8) & 0xFF]) << 8 | (ZUC_S1[F_R[1] & 0xFF]);
//
//	return W;
//};

  // F() function
  // F() critical path:
  // f_r_Q ==> 2 operands add ==> 5 operands xor ==> S-boxes lookup ==> f_r_D.   
  always @(*) begin
    f_w1 = f_r1 + br_x1;
    f_w2 = f_r2 ^ br_x2;
    f_w  = (br_x0 ^ f_r1) + f_r2;

    ////  rotl = (ina << inb) | (ina >> (32 - inb));
    ////  zuc_l1 = ina ^ rotl(ina, 2) ^ rotl(ina, 10) ^ rotl(ina, 18) ^ rotl(ina, 24);
    // f_u = zuc_l1({f_w1[15:0], f_w2[31:16]});
    f_ua = {f_w1[15:0], f_w2[31:16]};
    f_u = f_ua ^ {f_ua[29:0], f_ua[31:30]} ^ {f_ua[21:0], f_ua[31:22]} ^ {f_ua[13:0], f_ua[31:14]} ^ {f_ua[7:0], f_ua[31:8]};
    //
    // f_v = zuc_l2({f_w2[15:0], f_w1[31:16]});
    //  zuc_l2 = ina ^ rotl(ina, 8) ^ rotl(ina, 14) ^ rotl(ina, 22) ^ rotl(ina, 30);
    f_va = {f_w2[15:0], f_w1[31:16]};
    f_v = f_va ^ {f_va[23:0], f_va[31:24]} ^ {f_va[17:0], f_va[31:18]} ^ {f_va[9:0], f_va[31:10]} ^ {f_va[1:0], f_va[31:2]};
    
    // S-boxes lookup:
    zuc_s00_in = f_u[31:24];
    zuc_s01_in = f_u[15:8];
    zuc_s02_in = f_v[31:24];
    zuc_s03_in = f_v[15:8];
    zuc_s10_in = f_u[23:16];
    zuc_s11_in = f_u[7:0];
    zuc_s12_in = f_v[23:16];
    zuc_s13_in = f_v[7:0];
//    f_r1_D = {ZUC_S0[f_u >> 24) & 0xFF] << 24,
//	        ZUC_S1[f_u >> 16) & 0xFF] << 16, 
//	        ZUC_S0[f_u >>  8) & 0xFF] <<  8, 
//	        ZUC_S1[f_u        & 0xFF]};
//    f_r2_D = {ZUC_S0[f_v >> 24) & 0xFF] << 24, 
//	        ZUC_S1[f_v >> 16) & 0xFF] << 16, 
//	        ZUC_S0[f_v >>  8) & 0xFF] <<  8, 
//	        ZUC_S1[f_v        & 0xFF]};
    f_r1_D = {zuc_s00_out, zuc_s10_out, zuc_s01_out, zuc_s11_out};
    f_r2_D = {zuc_s02_out, zuc_s12_out, zuc_s03_out, zuc_s13_out};
  end
  

  always @(posedge zc_clk) begin
    if (zc_reset) begin
//      f_w  <= 32'h00000000;
      f_r1 <= 32'h00000000;
      f_r2 <= 32'h00000000;
    end
    else begin
//      f_w <= (br_x0 ^ f_r1) + f_r2;
      zc_keystream <= br_x3 ^ ((br_x0 ^ f_r1) + f_r2);
      if (zc_init)
	begin
	  f_r1 <= 32'h00000000;
	  f_r2 <= 32'h00000000;
	end
      else
	begin
	  f_r1 <= f_r1_D;
	  f_r2 <= f_r2_D;
	end
    end	
  end

  
// SBOX. Four separate instantiations per each S0 and S1 arrays, to allow 4 concurrent lookup operations to either of S0 and S1
// See F() for the various lookups details
// Distributed ROMs:
sbox_s0 zuc_s00 (
  .a(zuc_s00_in),      // input wire [7 : 0] a
  .spo(zuc_s00_out)  // output wire [7 : 0] spo
);
sbox_s0 zuc_s01 (
  .a(zuc_s01_in),      // input wire [7 : 0] a
  .spo(zuc_s01_out)  // output wire [7 : 0] spo
);
sbox_s0 zuc_s02 (
  .a(zuc_s02_in),      // input wire [7 : 0] a
  .spo(zuc_s02_out)  // output wire [7 : 0] spo
);
sbox_s0 zuc_s03 (
  .a(zuc_s03_in),      // input wire [7 : 0] a
  .spo(zuc_s03_out)  // output wire [7 : 0] spo
);

sbox_s1 zuc_s10 (
  .a(zuc_s10_in),      // input wire [7 : 0] a
  .spo(zuc_s10_out)  // output wire [7 : 0] spo
);  
sbox_s1 zuc_s11 (
  .a(zuc_s11_in),      // input wire [7 : 0] a
  .spo(zuc_s11_out)  // output wire [7 : 0] spo
);  
sbox_s1 zuc_s12 (
  .a(zuc_s12_in),      // input wire [7 : 0] a
  .spo(zuc_s12_out)  // output wire [7 : 0] spo
);  
sbox_s1 zuc_s13 (
  .a(zuc_s13_in),      // input wire [7 : 0] a
  .spo(zuc_s13_out)  // output wire [7 : 0] spo
);  

// LFSR
//LFSRWithInitialisationMode(u) {
//1. v=2p15s15+2p17s13+2p21s10+2p20s4+(1+2p8)s0 mod (2p31-1);
//2. s16=(v+u) mod (231-1);
//3. If s16=0, then set s16=2p31-1;
//4. (s1,s2, …,s15,s16)→(s0,s1, …,s14,s15).
//}
// Step 1 can be implemented as:
// v=(s15<<<15)+(s13<<<17)+(s10<<<21)+(s4<<<20)+(s0 <<<8)+s0 mod (2p31-1)


//
//unsigned int PowMod(unsigned int x, unsigned int k)
//{
//        return (((x << k) | (x >> (31 - k))) & 0x7fffffff);
//}
//
//#define MulByPow2(x, k) ((((x) << k) | ((x) >> (31 - k))) & 0x7FFFFFFF)
//  function mulPow2;
//    input ina, inb;
//    begin
//      mulPow2 = ((ina << inb) | (ina >> (31 - inb))) & 32'h7FFFFFFF;
//    end
//  endfunction // mulPow2
  
//* c = a + b mod (2^31 ¡V 1) */
//u32 AddM(u32 a, u32 b)
//{
//u32 c = a + b;
//return (c & 0x7FFFFFFF) + (c >> 31);
//}
//  function addMod;
//    input ina, inb;
//    begin
//      // TBD: Verify tha >> do logic shift rather than arith shift 
//      addMod = ((ina + inb) & 32'h7FFFFFFF) + ((ina + inb) >> 31);
//    end
//  endfunction // addMod

//  mulPow2 = ((ina << inb) | (ina >> (31 - inb))) & 32'h7FFFFFFF;
//
////  assign lfsr_s15p15 = {1'b0, lfsr_s15[15:0], lfsr_s15[31:17]};
//  assign lfsr_s15p15 = mulPow2(lfsr_s15, 15);
  assign lfsr_s15p15 = ((lfsr_s15 << 15) | (lfsr_s15 >> 16)) & 32'h7FFFFFFF;
//  assign lfsr_s13p17 = mulPow2(lfsr_s13, 17);
  assign lfsr_s13p17 = ((lfsr_s13 << 17) | (lfsr_s13 >> 14)) & 32'h7FFFFFFF;
//  assign lfsr_s10p21 = mulPow2(lfsr_s10, 21);
  assign lfsr_s10p21 = ((lfsr_s10 << 21) | (lfsr_s10 >> 10)) & 32'h7FFFFFFF;
//  assign lfsr_s4p20  = mulPow2(lfsr_s4, 20);
  assign lfsr_s4p20 = ((lfsr_s4 << 20) | (lfsr_s4 >> 11)) & 32'h7FFFFFFF;
//  assign lfsr_s0p8   = mulPow2(lfsr_s0, 8);
  assign lfsr_s0p8 = ((lfsr_s0 << 8) | (lfsr_s0 >> 23)) & 32'h7FFFFFFF;


  // lfsr_s16 calculation, using 7-input csa                                    //void LFSRWithInitialisationMode(u32 u)
//{
//u32 f, v;
//f = LFSR_S0;
//v = MulByPow2(LFSR_S0, 8);
//f = AddM(f, v);
//v = MulByPow2(LFSR_S4, 20);
//f = AddM(f, v);
//v = MulByPow2(LFSR_S10, 21);
//f = AddM(f, v);
//v = MulByPow2(LFSR_S13, 17);
//f = AddM(f, v);
//v = MulByPow2(LFSR_S15, 15);
//f = AddM(f, v);
//f = AddM(f, u);                                                               //}
  
      
// MOD addition special case:
// ==========================

// The EEA-128 specification suggests to implement the 7-operand addition with the following flow: 
//u32 f, v;
//f = LFSR_S0;
//v = MulByPow2(LFSR_S0, 8);
//f = AddM(f, v);
//v = MulByPow2(LFSR_S4, 20);
//f = AddM(f, v);
//v = MulByPow2(LFSR_S10, 21);
//f = AddM(f, v);
//v = MulByPow2(LFSR_S13, 17);
//f = AddM(f, v);
//v = MulByPow2(LFSR_S15, 15);
//f = AddM(f, v);
//f = AddM(f, W);
//}

// Following the above flow means doing MOD after each addition, which doubles number of additions, to total 12 additions.
// To relax the 7-operand addition, a regular 7 operand addition, using 7-input CSA,  followed by a single MOD operation.

// The MOD scheme, as prposed by the EEIA-128 spec is:
// (a+b) MOD (2^31 -1) = ((a + b) & 32'h7FFFFFFF) + ((a + b) >> 31);

// Yet, unfortunately, this MOD scheme do not work in the single MOD scheme.
// A counter example is described below, followed by a resolution.

// Test Case: A confidentiality message
//=====================================
// header[415:288] = key[127:0] = CK[15]-CK[0] = 290af0709404607a1d730350ba143d17
// header[287:160] = IV[127:0] = iv[15]-iv[0] = 00000078925403660000007892540366
// message[191:0] = flipped_IBS[191:0] = 5875b20bd675d96f9025fe0c9752fa735552ab6cf65340
// Keystream, length 6: ca3e0c86 19aed798 a66b77e2 b077a16a 05379169 307bf97a
// IBS length: 0xc0 bits == 0x18 == 24 bytes
// IBS: 6cf65340   735552ab   0c9752fa   6f9025fe   0bd675d9   005875b2
// OBS: a6c85fc6   6afb8533   aafc2518   dfe78494   0ee1e4b0   30238cc8
//
//
// While handling the above message, the second LFSRinit iteration, fails to add the following 7 operands:
// lfsr_s13p17=1ea6bc03
// lfsr_s13p17=530c776b
// lfsr_s13p17=340015e2
// lfsr_s13p17=325286bc
// lfsr_s13p17=200036bc
// lfsr_s13p17=26bc033d
// lfsr_s13p17=5d8b20ba
// Actual result before MOD: 17C4D2ABF
// Since the result is truncated into a 32bit, the MOD scheme do not modify the result, thus the final sum is 7C4D2ABF.
// On the other hand, using the reference C code (provided by the EEIA-128 spec, the expected result should be: 7C4D2AC1
//
// While analyzing this diff, it is obvious that the result before MOD have the 33th bit asserted.
// This 'carry' bit is a result of adding multiple numbers, without intermmediate MOD operations, thus possibly ending with a too high sum result to fit into 32bit
//
// To resolve this, and still do only a single MOD, the addition is stored into a wider register, such that maintaining all the possible carry value.
// Theoretically, adding 7 numbers of 31 bits each, may end with extra 3 carry bits.
// For example, adding 7 numbers, each the maximum 31bit value:
// sum[33:0] = 7fffffff x 7 = 37FFFFFF9
// In this extreme example there are 3 carry bits, [33:31], beyond the added 31bit operands.
//
// So, a proper single MOD operation will be:
// 1. sum[33:0] = 7-oprands-adder();
// 2. MOD(sum[31:0], 2^31 - 1) = {0, sum[30:0]} + {29'h0000000, sum[33:31]}
// 
  
  // MOD addition 
  // Unlike implemented in ZUC C rereference, whis is:
  // (((a + b) mod M) + d mod M) + ...) mod M 
  // a more timing-friendly implementation is implemented:
  // (a mod M + b mod M + c mod M + ...) mod M
  // Notice that in zuc implementation, all operands are 'mod M' anyway
  // Proof Source: https://www.khanacademy.org/computing/computer-science/cryptography/modarithmetic/a/modular-addition-and-subtraction

  assign f_w_cond = zc_lfsrwithinit ? {1'b0, f_w[31:1]} : 32'h00000000;

  csa_32x7 csa_32x7(
		    .in1({4'h0, lfsr_s15p15}),
		    .in2({4'h0, lfsr_s13p17}),
		    .in3({4'h0, lfsr_s10p21}),
		    .in4({4'h0, lfsr_s4p20}),
		    .in5({4'h0, lfsr_s0p8}),
		    .in6({4'h0, lfsr_s0}),
		    .in7({4'h0, f_w_cond}),
		    .sum(lfsr_s16_sum),
		    .carry(lfsr_s16_carry)
		    );
  /*
   lfsr_s16_sc1 = {4'h0, lfsr_s15p15} +
   {4'h0, lfsr_s13p17} +
   {4'h0, lfsr_s10p21} +
   {4'h0, lfsr_s4p20} +
   {4'h0, lfsr_s0p8} +
   {4'h0, lfsr_s0} +
   {4'h0, f_w_cond};
   */
  
  always @(*)
	   begin
	     lfsr_s16_sc1 = lfsr_s16_sum + {lfsr_s16_carry[34:0], 1'b0};
	     lfsr_s16_sc2 = {1'b0, lfsr_s16_sc1[30:0]};
	     lfsr_s16_msb = lfsr_s16_sc1[35:31];
	     lfsr_s16 = lfsr_s16_sc2 + {27'h0000000, lfsr_s16_msb[4:0]};
	   end
  
endmodule

// 7-input carry save adder
module csa_32x7(
                input wire [35:0]  in1,
        	input wire [35:0]  in2,
                input wire [35:0]  in3,
                input wire [35:0]  in4,
                input wire [35:0]  in5,
                input wire [35:0]  in6,
                input wire [35:0]  in7,
                output wire [35:0] sum,
                output wire [35:0] carry
                );

  wire [35:0] 			   sum1;
  wire [35:0] 			   sum2;
  wire [35:0] 			   sum3;
  wire [35:0]                      sum4;
  wire [35:0]                      carry1;
  wire [35:0]                      carry2;
  wire [35:0]                      carry3;
  wire [35:0]                      carry4;

  csa_32x3 csa_32x3_1(
                      .in1(in1),
                      .in2(in2),
                      .in3(in3),
                      .sum(sum1),
                      .carry(carry1)
                      );

  csa_32x3 csa_32x3_2(
                      .in1(in4),
                      .in2(in5),
                      .in3(in6),
                      .sum(sum2),
                      .carry(carry2)
                      );
  
  csa_32x3 csa_32x3_3(
                      .in1(sum1),
                      .in2(sum2),
                      .in3({carry1[34:0], 1'b0}),
                      .sum(sum3),
                      .carry(carry3)
                      );
  
  csa_32x3 csa_32x3_4(
                      .in1(sum3),
                      .in2({carry2[34:0], 1'b0}),
                      .in3({carry3[34:0], 1'b0}),
                      .sum(sum4),
                      .carry(carry4)
                      );
  
  csa_32x3 csa_32x3_5(
                      .in1(in7),
                      .in2(sum4),
                      .in3({carry4[34:0], 1'b0}),
                      .sum(sum),
                      .carry(carry)
                      );
  
endmodule // csa_32x6


module csa_32x3(
                input wire [35:0]  in1,
		input wire [35:0]  in2,
                input wire [35:0]  in3,
                output wire [35:0] sum,
                output wire [35:0] carry
                );

  assign sum = in1 ^ in2 ^ in3;
  assign carry = in1 & in2 | in1 & in3 | in2 & in3;
  
endmodule // csa_32x3      

