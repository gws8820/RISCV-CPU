typedef enum logic [1:0] {
    FWDA_EX,
    FWDA_MEM,
    FWDA_WB
} forwarda_t;

typedef enum logic [1:0] {
    FWDB_EX,
    FWDB_MEM,
    FWDB_WB
} forwardb_t;

typedef struct packed {
    logic           raw_data;
    logic           store_data;
    logic           load_use;
    logic           branch_mispredict;
} hazard_cause_t;

typedef struct packed {
    pcsrc_t         pcsrc;
    logic [4:0]     rs1_d, rs1_e;
    logic [4:0]     rs2_d, rs2_e, rs2_m;
    logic [4:0]     rd_e, rd_m, rd_w;
    logic           regwrite_m, regwrite_w;
    memaccess_t     memaccess_e, memaccess_m;
    logic           flushflag;
} hazard_req_t;

typedef struct packed {
    hazard_cause_t  hazard_cause;
    logic           stall_f, stall_d, flush_d, flush_e, flush_m;
    forwarda_t      forward_a;
    forwardb_t      forward_b;
    logic           forward_mem;
} hazard_res_t;