localparam int  CLK_FREQ        = 120_000_000;
localparam real CLK_PERIOD      = 1_000_000_000.0 / CLK_FREQ;   // ns

localparam DEBOUNCE_LIMIT       = 500000;                       // 10ms
localparam DEBOUNCE_BITS        = $clog2(DEBOUNCE_LIMIT);

localparam IMEM_WORD            = 4 * 1024;                     // 16KB
localparam DMEM_WORD            = 16 * 1024;                    // 64KB

localparam BOOT_MSG             = 32'hABCD_1234;
localparam PRINT_ADDR           = 32'hFFFF_0000;