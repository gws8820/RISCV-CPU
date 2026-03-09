localparam int  CLK_FREQ        = 100_000_000;
localparam real CLK_PERIOD      = 1_000_000_000.0 / CLK_FREQ;   // ns

localparam DEBOUNCE_LIMIT       = 500000;                       // 10ms
localparam DEBOUNCE_BITS        = $clog2(DEBOUNCE_LIMIT);

localparam IMEM_WORD            = 128 * 256;                    // 128KB
localparam DMEM_WORD            = 128 * 256;                    // 128KB

localparam MUL_COUNT            = 3;
localparam DIV_COUNT            = 17;
localparam SHIFT_COUNT          = DIV_COUNT - 1;

localparam BOOT_MSG             = 32'hABCD_1234;
localparam DMEM_ADDR            = 32'h0002_0000;
localparam PRINT_ADDR           = 32'hFFFF_0000;
localparam INPUT_ADDR           = 32'hFFFF_0004;