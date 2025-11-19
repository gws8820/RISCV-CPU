typedef enum logic [1:0] {
    TRAP_NONE       = 2'b00,
    TRAP_ENTER      = 2'b01,
    TRAP_RETURN     = 2'b10
} trap_mode_t;

typedef enum logic [31:0] {
  CAUSE_INST_MISALIGNED     = 32'd0,
  CAUSE_INST_ACCESS_FAULT   = 32'd1,
  CAUSE_ILLEGAL_INSTRUCTION = 32'd2,
  CAUSE_BREAKPOINT          = 32'd3,
  CAUSE_LOAD_ADDR_MISALIGN  = 32'd4,
  CAUSE_LOAD_ACCESS_FAULT   = 32'd5,
  CAUSE_STORE_ADDR_MISALIGN = 32'd6,
  CAUSE_STORE_ACCESS_FAULT  = 32'd7,
  CAUSE_ECALL_MMODE         = 32'd11
} trap_cause_t;

typedef struct packed {
    logic           instillegal;
    logic           instmisalign;
    logic           imemfault;
    logic           datamisalign;
    logic           dmemfault;
} trap_flag_t;

typedef struct packed {
    logic           valid;
    trap_mode_t     mode; // [1] mret, [0] trap
    trap_cause_t    cause;
    logic [31:0]    pc;
    logic [31:0]    tval;
} trap_req_t;

typedef struct packed {
    logic           redirflag;
    logic [31:0]    rediraddr;
    logic           flushflag;
} trap_res_t;