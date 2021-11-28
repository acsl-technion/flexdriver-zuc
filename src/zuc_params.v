//`define TWO_SLICES
// AXI4LITE_EN is used in zuc_top.v (image build top)
`define AXI4LITE_EN

// Select which sample buffer to deploy.
// Keep in mind that each buffer consumes 115 x 36Kb_BRAMs
//`define FLC_PCI2SBU_SAMPLE_EN
`define AFU_PCI2SBU_SAMPLE_EN
`define INPUT_BUFFER_SAMPLE_EN
`define MODULE_IN_SAMPLE_EN
`define AFU_SBU2PCI_SAMPLE_EN
`define FLC_SBU2PCI_SAMPLE_EN

localparam
  BUFFER_RAM_SIZE           = 8*1024,    // Total input RAM size: 8K lines x 512b/line
  NUM_CHANNELS              = 16,      // Number of implemented channels
  MAX_PACKET_SIZE           = 1024,    // Max packet size transfer on sbu2pci port. Default to 1KB.
  CHANNEL_BUFFER_SIZE       = BUFFER_RAM_SIZE/NUM_CHANNELS, // Total number of 512b lines per channel 
  CHANNEL_BUFFER_SIZE_WATERMARK = 4,  // Minimum number of free 512b lines before 'full' indication 
  CHANNEL_BUFFER_MAX_CAPACITY = CHANNEL_BUFFER_SIZE - CHANNEL_BUFFER_SIZE_WATERMARK,  // Maximum allowd capacity, considering the WATERMARK
  FULL_LINE_KEEP            = 64'hffffffffffffffff,
  MAC_RESPONSE_KEEP         = 64'hffffffffffff0000, // tdata[127:0] should be masked !!
  FIFO_LINE_SIZE            = 64,      // # of bytes per input buffer/fifo_in/fifo_out line 
  MODULE_FIFO_IN_SIZE       = 16'd514, // # Max utilized entries num in fifox_in (actual max size is 515)
  MODULE_FIFO_OUT_SIZE      = 16'd514, // # Max utilized entries num in fifox_out (actual max size is 515)
  ZUC_AFU_FREQ              = 12'h0c8; // == 'd200. Default zuc clock frequency (Mhz). Can be reconfigured in zuc_ctrlTBD
// Used for modules utilization & tpt calc.

// 512b sampling buffers:
localparam
  SAMPLE_FIFO_SIZE       = 8*1024,
  SAMPLE_FIFO_WATERMARK  = SAMPLE_FIFO_SIZE - 'd8;



localparam
  NUMBER_OF_MODULES         = 'd8;    // Number of zuc modules: between 1 thru 8. Higher values are forced to 8.

localparam [7:0]
  // All opcodes > 3 are treated as illegal opcodes, and the associated message is bypassed (from input_buffer to sbu2pci)
  MESSAGE_CMD_CONF          = 8'h00,
  MESSAGE_CMD_INTEG         = 8'h01,
  MESSAGE_CMD_AFUBYPASS     = 8'h02,
  MESSAGE_CMD_MODULEBYPASS  = 8'h03,
  MESSAGE_CMD_NOP           = 8'h04;

//Ethernet/ip/udp headers fields
`define ETH_DST       511:464     // 6 bytes
`define ETH_SRC       463:416     // 6 bytes
`define ETH_TYPE      415:400     // 2 bytes
`define IP_VERSION    399:384     // 2 bytes
`define IP_LEN        383:368     // 2 bytes
`define IP_FLAGS      367:320     // 6 bytes  
`define IP_CHKSM      319:304     // 2 bytes  
`define IP_DST        303:272     // 4 bytes
`define IP_SRC        271:240     // 4 bytes
`define UDP_DST       239:224     // 2 bytes
`define UDP_SRC       223:208     // 2 bytes
`define UDP_LEN       207:192     // 2 bytes
`define UDP_CHKSM     191:176     // 2 bytes
`define HEADER_TAIL   175:60
`define HEADER_METADATA 59:0

// AFU/Modules bypass mode:
localparam [1:0]
  FORCE_ZUC_CORE_BYPASS = 2'b01,
  FORCE_AFU_BYPASS      = 2'b10,
  FORCE_MODULE_BYPASS   = 2'b11;

// Packets payload size buckets:
localparam
  SIZE_BUCKET0  = 'd0,      // payload size == 0 (i.e: Integrity response is header_only)
  SIZE_BUCKET1  = 'd64,     // payload size <= 64
  SIZE_BUCKET2  = 'd128,    // payload size <= 128
  SIZE_BUCKET3  = 'd256,    // payload size <= 256
  SIZE_BUCKET4  = 'd512,    // payload size <= 512
  SIZE_BUCKET5  = 'd1024,   // payload size <= 1024
  SIZE_BUCKET6  = 'd2048,   // payload size <= 2048
  SIZE_BUCKET7  = 'd4096,   // payload size <= 4096
  SIZE_BUCKET8  = 'd8192,   // payload size <= 8192
  SIZE_BUCKET9  = 'd9216,   // payload size <= 9216
  SIZE_BUCKET10 = 'd9216;   // payload size >  9216

localparam [2:0]
  // histogram arrays
  HIST_ARRAY_PCI2SBU_PACKETS     = 3'b000,
  HIST_ARRAY_PCI2SBU_EOMPACKETS  = 3'b001,
  HIST_ARRAY_PCI2SBU_MESSAGES    = 3'b010,
  HIST_ARRAY_SBU2PCI_RESPONSES   = 3'b011;

localparam [1:0]
  // histogram clear operations
  HIST_OP_CLEAR_NOP           = 2'b00,
  HIST_OP_CLEAR_CHID          = 2'b01,
  HIST_OP_CLEAR_ARRAY         = 2'b10,
  HIST_OP_CLEAR_ALL           = 2'b11;

localparam [19:0]
  // axi4stream samplers read_address base
  FLC_CLK_PCI2SBU             = 20'h10000,
  FLC_CLK_SBU2PCI             = 20'h10100,
  AFU_CLK_PCI2SBU             = 20'h08000,
  AFU_CLK_SBU2PCI             = 20'h08100,
  AFU_CLK_MODULE_IN           = 20'h08200,
  AFU_CLK_INPUT_BUFFER        = 20'h08300;

localparam [7:0]
  // Soft reset duration, in zuc_clk ticks
  AFU_SOFT_RESET_WIDTH        = 8'h30,
  PCI_SAMPLE_SOFT_RESET_WIDTH = 8'h20;

localparam
  AXILITE_TIMEOUT = 8'd64;     // Max axilite read/write response latency. After which the axilite_timeout_slave will respond
