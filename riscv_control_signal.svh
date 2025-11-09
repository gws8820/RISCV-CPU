// Branch Unit
typedef enum logic [1:0] {
    PC_REDIR,
    PC_PLUS4,
    PC_PLUSIMM,
    PC_ALU
} pcsrc_t;

typedef enum logic [1:0] {
    NEXTPC_PLUS4,
    NEXTPC_BRANCH,
    NEXTPC_JAL,
    NEXTPC_JALR
} nextpc_mode_t;

typedef enum logic [1:0] {
    CFLOW_NORMAL,
    CFLOW_ECALL,
    CFLOW_EBREAK,
    CFLOW_MRET
} cflow_mode_t;

typedef enum logic [2:0] {
    BRANCH_BEQ      = 3'b000,
    BRANCH_BNE      = 3'b001,
    BRANCH_BLT      = 3'b100,
    BRANCH_BGE      = 3'b101,
    BRANCH_BLTU     = 3'b110,
    BRANCH_BGEU     = 3'b111
} branch_mode_t;

typedef enum logic [2:0] {
    MASK_BYTE       = 3'b000,
    MASK_HALF       = 3'b001,
    MASK_WORD       = 3'b010,
    MASK_BYTE_U     = 3'b100,
    MASK_HALF_U     = 3'b101
} mask_mode_t;

typedef enum logic [2:0] {
    CSR_NOP         = 3'b000,
    CSR_RW          = 3'b001,
    CSR_RS          = 3'b010,
    CSR_RC          = 3'b011,
    CSR_RWI         = 3'b101,
    CSR_RSI         = 3'b110,
    CSR_RCI         = 3'b111
} csr_mode_t;

typedef union packed {
    branch_mode_t   branch_mode;
    mask_mode_t     mask_mode;
    csr_mode_t      csr_mode;
} funct3_t;

typedef struct packed {
    logic           valid;
    logic           use_imm;
    csr_mode_t      csr_mode;
    logic [11:0]    csr_target;
} csr_pkt_t;

typedef enum logic [2:0] {
    IMM_I,
    IMM_S,
    IMM_B,
    IMM_U,
    IMM_J,
    IMM_Z
} immsrc_t;

typedef enum logic [1:0] {
    SRCA_REG,
    SRCA_PC,
    SRCA_ZERO
} alusrca_t;

typedef enum logic [0:0] {
    SRCB_REG,
    SRCB_IMM
} alusrcb_t;

// Internal Signal of Control Unit
typedef enum logic [0:0] {
    ALUOP_ADD,
    ALUOP_ARITH
} aluop_t;

typedef enum logic [3:0] {
    ALU_ADD,
    ALU_SUB,
    ALU_SLT,
    ALU_SLTU,
    ALU_XOR,
    ALU_OR,
    ALU_AND,
    ALU_SLL,
    ALU_SRL,
    ALU_SRA
} alucontrol_t;

typedef enum logic [1:0] {
    MEM_DISABLED,
    MEM_READ,
    MEM_WRITE
} memaccess_t;

typedef enum logic [1:0] {
    RESULT_ALU,
    RESULT_MEM,
    RESULT_PCPLUS4,
    RESULT_CSR
} resultsrc_t;

typedef struct packed {
    nextpc_mode_t   nextpc_mode;
    cflow_mode_t    cflow_mode;
    funct3_t        funct3;
    csr_pkt_t       csr_pkt;
    logic           fencei;
    immsrc_t        immsrc;
    alusrca_t       alusrc_a;
    alusrcb_t       alusrc_b;
    alucontrol_t    alucontrol;
    memaccess_t     memaccess;
    resultsrc_t     resultsrc;
    logic           regwrite;
} control_signal_t;