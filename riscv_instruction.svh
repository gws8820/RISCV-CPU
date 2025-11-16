localparam INST_NOP = 32'h00000013; // ADDI x0, x0, 0

typedef enum logic [6:0] {
    OP_OP           = 7'b01_100_11,
    OP_OPIMM        = 7'b00_100_11,
    OP_LOAD         = 7'b00_000_11,
    OP_STORE        = 7'b01_000_11,
    OP_LUI          = 7'b01_101_11,
    OP_AUIPC        = 7'b00_101_11,
    OP_BRANCH       = 7'b11_000_11,
    OP_JALR         = 7'b11_001_11,
    OP_JAL          = 7'b11_011_11,
    OP_MISC_MEM     = 7'b00_011_11,
    OP_SYSTEM       = 7'b11_100_11
} opcode_t;

typedef struct packed {
    logic [6:0]     funct7;
    logic [4:0]     rs2;
    logic [4:0]     rs1;
    logic [2:0]     funct3;
    logic [4:0]     rd;
    opcode_t opcode;
} inst_r_t;

typedef struct packed {
    logic [11:0]    imm;
    logic [4:0]     rs1;
    logic [2:0]     funct3;
    logic [4:0]     rd;
    opcode_t opcode;
} inst_i_t;

typedef struct packed {
    logic [6:0]     imm11_5;
    logic [4:0]     rs2;
    logic [4:0]     rs1;
    logic [2:0]     funct3;
    logic [4:0]     imm4_0;
    opcode_t        opcode;
} inst_s_t;

typedef struct packed {
    logic           imm12;
    logic [5:0]     imm10_5;
    logic [4:0]     rs2;
    logic [4:0]     rs1;
    logic [2:0]     funct3;
    logic [4:1]     imm4_1;
    logic           imm11;
    opcode_t        opcode;
} inst_b_t;

typedef struct packed {
    logic [19:0]    imm31_12;
    logic [4:0]     rd;
    opcode_t        opcode;
} inst_u_t;

typedef struct packed {
    logic           imm20;
    logic [9:0]     imm10_1;
    logic           imm11;
    logic [7:0]     imm19_12;
    logic [4:0]     rd;
    opcode_t        opcode;
} inst_j_t;

typedef union packed {
    inst_r_t        r;
    inst_i_t        i;
    inst_s_t        s;
    inst_b_t        b;
    inst_u_t        u;
    inst_j_t        j;
} inst_t;