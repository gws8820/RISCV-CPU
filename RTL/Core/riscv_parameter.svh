localparam int  CLK_FREQ        = 100_000_000;
localparam real CLK_PERIOD      = 1_000_000_000.0 / CLK_FREQ;   // ns

localparam DEBOUNCE_LIMIT       = 500000;                       // 10ms
localparam DEBOUNCE_BITS        = $clog2(DEBOUNCE_LIMIT);

localparam ROM_SIZE_BYTE        = 128 * 1024;
localparam RAM_SIZE_BYTE        = 128 * 1024;
localparam ROM_SIZE_WORD        = ROM_SIZE_BYTE / 4;
localparam RAM_SIZE_WORD        = RAM_SIZE_BYTE / 4;

localparam MUL_COUNT            = 3;
localparam DIV_COUNT            = 17;
localparam SHIFT_COUNT          = DIV_COUNT - 1;

localparam BOOT_MSG             = 32'hABCD_1234;
localparam ROM_BASE_ADDR        = 32'h0000_0000;
localparam RAM_BASE_ADDR        = 32'h0002_0000;
localparam MMIO_PRINT_ADDR      = 32'hFFFF_0000;
localparam MMIO_INPUT_ADDR      = 32'hFFFF_0004;

localparam ROM_BASE_WORD        = ROM_BASE_ADDR[31:2];
localparam RAM_BASE_WORD        = RAM_BASE_ADDR[31:2];
localparam MMIO_PRINT_WORD      = MMIO_PRINT_ADDR[31:2];
localparam MMIO_INPUT_WORD      = MMIO_INPUT_ADDR[31:2];