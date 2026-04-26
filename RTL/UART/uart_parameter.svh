localparam BAUD_RATE        = 115200;
localparam OVERSAMPLE_RATE  = 16;
localparam OVERSAMPLE_BITS  = $clog2(OVERSAMPLE_RATE);

localparam START_FLAG       = 8'hA5;

localparam INPUT_FIFO_SIZE  = 64;
localparam INPUT_FIFO_BITS  = $clog2(INPUT_FIFO_SIZE);

localparam PRINT_FIFO_SIZE  = 2048;
localparam PRINT_FIFO_BITS  = $clog2(PRINT_FIFO_SIZE);
