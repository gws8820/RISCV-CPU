typedef enum logic [1:0] {
    FWD_ID,
    FWD_EX,
    FWD_MEM,
    FWD_WB
} forward_t;

typedef struct packed {
    logic           raw_data_id;
    logic           raw_data_ex;
    logic           store_data;
    logic           load_use;
    logic           branch_mispredict;
} hazard_cause_t;

typedef struct packed {
    cflow_mode_t    cflow_mode;
    logic           mispredict;
    logic [4:0]     rs1_d, rs1_e;
    logic [4:0]     rs2_d, rs2_e, rs2_m;
    logic [4:0]     rd_e, rd_m, rd_w;
    logic           regwrite_e, regwrite_m, regwrite_w;
    memaccess_t     memaccess_e, memaccess_m;
    logic           flushflag;
} hazard_req_t;

typedef struct packed {
    hazard_cause_t  hazard_cause;
    logic           stall_f, stall_d, flush_d, flush_e, flush_m;
    forward_t       forwarda_d, forwardb_d, forwarda_e, forwardb_e;
    logic           forward_mem;
} hazard_res_t;