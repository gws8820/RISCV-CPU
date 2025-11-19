timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_unit (
    input   logic                   start,
    hazard_interface.completer      hazard_bus
);
    logic flush_d_sd, flush_e_lu, flush_e_bm;
    
    always_comb begin
        if (!start) begin
            hazard_bus.res = '0;
        end
        else begin
            hazard_bus.res.flush_d  = hazard_bus.req.flushflag || flush_d_sd;
            hazard_bus.res.flush_e  = hazard_bus.req.flushflag || flush_e_lu || flush_e_bm;
            hazard_bus.res.flush_m  = hazard_bus.req.flushflag;
        end
    end
    
    raw_data_forwarder raw_data_forwarder(
        .regwrite_m                 (hazard_bus.req.regwrite_m),
        .regwrite_w                 (hazard_bus.req.regwrite_w),
        .rs1_e                      (hazard_bus.req.rs1_e),
        .rs2_e                      (hazard_bus.req.rs2_e),
        .rd_m                       (hazard_bus.req.rd_m),
        .rd_w                       (hazard_bus.req.rd_w),
        .flag                       (hazard_bus.res.hazard_cause.raw_data),
        .forward_a                  (hazard_bus.res.forward_a),
        .forward_b                  (hazard_bus.res.forward_b)
    );
    
    store_data_forwarder store_data_forwarder(
        .memaccess_m                (hazard_bus.req.memaccess_m),
        .rd_w                       (hazard_bus.req.rd_w),
        .rs2_m                      (hazard_bus.req.rs2_m),
        .flag                       (hazard_bus.res.hazard_cause.store_data),
        .forward_mem                (hazard_bus.res.forward_mem)
    );
    
    load_use_resolver load_use_resolver(
        .memaccess_e                (hazard_bus.req.memaccess_e),
        .rd_e                       (hazard_bus.req.rd_e),
        .rs1_d                      (hazard_bus.req.rs1_d),
        .rs2_d                      (hazard_bus.req.rs2_d),
        .flag                       (hazard_bus.res.hazard_cause.load_use),
        .stall_f                    (hazard_bus.res.stall_f),
        .stall_d                    (hazard_bus.res.stall_d),
        .flush_e                    (flush_e_lu)
    );
    
    branch_mispredict_resolver branch_mispredict_resolver(
        .pcsrc                      (hazard_bus.req.pcsrc),
        .flag                       (hazard_bus.res.hazard_cause.branch_mispredict),
        .flush_d                    (flush_d_sd),
        .flush_e                    (flush_e_bm)
    );
    
endmodule