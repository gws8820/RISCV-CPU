localparam int unsigned CLK_FREQ          = 100_000_000;
localparam real         CLK_PERIOD        = 1_000_000_000.0 / CLK_FREQ;   // ns

localparam int unsigned DEBOUNCE_LIMIT    = CLK_FREQ / 100;                // 10ms
localparam int unsigned DEBOUNCE_BITS     = $clog2(DEBOUNCE_LIMIT);

localparam int unsigned ROM_SIZE_BYTE     = 128 * 1024;
localparam int unsigned RAM_SIZE_BYTE     = 128 * 1024;
localparam int unsigned ROM_SIZE_WORD     = ROM_SIZE_BYTE / 4;
localparam int unsigned RAM_SIZE_WORD     = RAM_SIZE_BYTE / 4;

localparam logic [31:0] ROM_BASE_ADDR     = 32'h0000_0000;
localparam logic [31:0] RAM_BASE_ADDR     = 32'h0002_0000;
localparam logic [31:0] MMIO_PRINT_ADDR   = 32'hFFFF_0000;
localparam logic [31:0] MMIO_INPUT_ADDR   = 32'hFFFF_0004;

localparam logic [29:0] ROM_BASE_WORD     = ROM_BASE_ADDR[31:2];
localparam logic [29:0] RAM_BASE_WORD     = RAM_BASE_ADDR[31:2];
localparam logic [29:0] MMIO_PRINT_WORD   = MMIO_PRINT_ADDR[31:2];
localparam logic [29:0] MMIO_INPUT_WORD   = MMIO_INPUT_ADDR[31:2];
