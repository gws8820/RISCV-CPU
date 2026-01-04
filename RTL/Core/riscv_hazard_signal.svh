typedef enum logic [1:0] {
    FWD_EX,
    FWD_MEM1,
    FWD_MEM2,
    FWD_WB
} forward_e_t;

typedef struct packed {
    logic           raw_data;
    logic           store_data;
    logic           load_use;
    logic           branch_mispredict;
} hazard_cause_t;

typedef struct packed {
    logic           flushflag;
    logic           mispredict;
    logic [4:0]     rs1_d, rs1_e;
    logic [4:0]     rs2_d, rs2_e, rs2_m1;
    logic [4:0]     rd_e, rd_m1, rd_m2, rd_w;
    logic           regwrite_m1, regwrite_m2, regwrite_w;
    memaccess_t     memaccess_e, memaccess_m1, memaccess_m2;
} hazard_req_t;

typedef struct packed {
    hazard_cause_t  hazard_cause;
    logic           stall_f, stall_d;
    logic           flush_d, flush_e, flush_m1, flush_m2;
    forward_e_t     forwarda_e, forwardb_e;
    logic           forward_m1;
} hazard_res_t;