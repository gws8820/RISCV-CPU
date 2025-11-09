timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_unit (
    input   start,
    input   hazard_req_t    hazard_req,
    output  hazard_res_t    hazard_res
);
    logic flush_d_sd, flush_e_lu, flush_e_bm;
    
    always_comb begin
        if (!start) begin
            hazard_res = '0;
        end
        else begin
            hazard_res.flush_d = hazard_req.flushflag || flush_d_sd;
            hazard_res.flush_e = hazard_req.flushflag || flush_e_lu || flush_e_bm;
            hazard_res.flush_m = hazard_req.flushflag;
        end
    end
    
    raw_data_forwarder raw_data_forwarder(
        .regwrite_m  (hazard_req.regwrite_m),
        .regwrite_w  (hazard_req.regwrite_w),
        .rs1_e       (hazard_req.rs1_e),
        .rs2_e       (hazard_req.rs2_e),
        .rd_m        (hazard_req.rd_m),
        .rd_w        (hazard_req.rd_w),
        .flag        (hazard_res.hazard_cause.raw_data),
        .forward_a   (hazard_res.forward_a),
        .forward_b   (hazard_res.forward_b)
    );
    
    store_data_forwarder store_data_forwarder(
        .memaccess_m (hazard_req.memaccess_m),
        .rd_w        (hazard_req.rd_w),
        .rs2_m       (hazard_req.rs2_m),
        .flag        (hazard_res.hazard_cause.store_data),
        .forward_mem (hazard_res.forward_mem)
    );
    
    load_use_resolver load_use_resolver(
        .memaccess_e (hazard_req.memaccess_e),
        .rd_e        (hazard_req.rd_e),
        .rs1_d       (hazard_req.rs1_d),
        .rs2_d       (hazard_req.rs2_d),
        .flag        (hazard_res.hazard_cause.load_use),
        .stall_f     (hazard_res.stall_f),
        .stall_d     (hazard_res.stall_d),
        .flush_e     (flush_e_lu)
    );
    
    branch_mispredict_resolver branch_mispredict_resolver(
        .pcsrc       (hazard_req.pcsrc),
        .flag        (hazard_res.hazard_cause.branch_mispredict),
        .flush_d     (flush_d_sd),
        .flush_e     (flush_e_bm)
    );
    
endmodule