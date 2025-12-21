localparam CLK_PERIOD           = 10;
localparam CLK_FREQ             = 1000000000 / CLK_PERIOD;      // 100MHz

localparam DEBOUNCE_LIMIT       = 500000;                       // 10ms
localparam DEBOUNCE_BITS        = $clog2(DEBOUNCE_LIMIT);

localparam IMEM_WORD            = 4 * 1024;                     // 16KB
localparam DMEM_WORD            = 16 * 1024;                    // 64KB

localparam BOOT_MSG             = 32'hABCD_1234;
localparam PRINT_ADDR           = 32'hFFFF_0000;