localparam BAUD_RATE        = 115200;
localparam OVERSAMPLE_RATE  = 16;
localparam OVERSAMPLE_BITS  = $clog2(OVERSAMPLE_RATE);

localparam START_FLAG       = 8'hA5;

localparam CTRL_FIFO_SIZE   = 32;   // Entries
localparam CTRL_FIFO_BITS   = $clog2(CTRL_FIFO_SIZE);

localparam PHY_FIFO_SIZE    = 256;  // Bytes (= CTRL_FIFO_SIZE * 8)
localparam PHY_FIFO_BITS    = $clog2(PHY_FIFO_SIZE);