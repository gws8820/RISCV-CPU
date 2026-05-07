localparam int unsigned BAUD_RATE             = 115_200;
localparam int unsigned OVERSAMPLE_RATE       = 16;
localparam int unsigned OVERSAMPLE_BITS       = $clog2(OVERSAMPLE_RATE);

localparam logic [7:0]  START_FLAG            = 8'hA5;

localparam int unsigned INPUT_FIFO_SIZE       = 64;
localparam int unsigned INPUT_FIFO_BITS       = $clog2(INPUT_FIFO_SIZE);

localparam int unsigned PRINT_FIFO_SIZE       = 2048;
localparam int unsigned PRINT_FIFO_BITS       = $clog2(PRINT_FIFO_SIZE);
