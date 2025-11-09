localparam CLK_PERIOD           = 10; // 10ns, 100MHz

localparam IMEM_WORD            = 4 * 1024; // 16KB
localparam DMEM_WORD            = 16 * 1024; // 64KB

localparam INST_NOP             = 32'h00000013; // ADDI x0, x0, 0

localparam FUNCT3_FENCEI        = 3'b001;