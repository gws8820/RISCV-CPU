localparam BAUD_RATE        = 115200;
localparam OVERSAMPLE_RATE  = 16;
localparam OVERSAMPLE_BITS  = $clog2(OVERSAMPLE_RATE);

localparam START_FLAG       = 8'hA5;
localparam IDLE_FLAG        = 8'hFF;

localparam FIFO_SIZE        = 128;
localparam FIFO_BITS        = $clog2(FIFO_SIZE);