localparam int  CLK_FREQ        = 120_000_000;
localparam real CLK_PERIOD      = 1_000_000_000.0 / CLK_FREQ;   // ns

localparam DEBOUNCE_LIMIT       = 500000;                       // 10ms
localparam DEBOUNCE_BITS        = $clog2(DEBOUNCE_LIMIT);

localparam IMEM_WORD            = 128 * 256;                    // 128KB
localparam DMEM_WORD            = 256 * 256;                    // 256KB

localparam MUL_COUNT            = 2;
localparam DIV_COUNT            = 33;
localparam SHIFT_COUNT          = DIV_COUNT - 1;

localparam BOOT_MSG             = 32'hABCD_1234;
localparam PRINT_ADDR           = 32'hFFFF_0000;