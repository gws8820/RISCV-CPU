timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_unit (
    hazard_interface.completer      hazard_bus
);
    logic flush_mispredict, flush_loaduse;
    always_comb begin
        hazard_bus.res.flush_d              = hazard_bus.req.flushflag || flush_mispredict;
        hazard_bus.res.flush_e              = hazard_bus.req.flushflag || flush_mispredict || flush_loaduse;
        hazard_bus.res.flush_m1             = hazard_bus.req.flushflag || flush_mispredict;
        hazard_bus.res.flush_m2             = hazard_bus.req.flushflag;
    end

    logic stall_f, stall_d;
    always_comb begin
        hazard_bus.res.stall_f              = stall_f && !hazard_bus.res.flush_d;
        hazard_bus.res.stall_d              = stall_d && !hazard_bus.res.flush_d;
    end
    
    hazard_raw_data_forwarder           hazard_raw_data_forwarder(
        .regwrite_m1                        (hazard_bus.req.regwrite_m1),
        .regwrite_m2                        (hazard_bus.req.regwrite_m2),
        .regwrite_w                         (hazard_bus.req.regwrite_w),
        .memaccess_m1                       (hazard_bus.req.memaccess_m1),
        .memaccess_m2                       (hazard_bus.req.memaccess_m2),
        .rs1_e                              (hazard_bus.req.rs1_e),
        .rs2_e                              (hazard_bus.req.rs2_e),
        .rd_m1                              (hazard_bus.req.rd_m1),
        .rd_m2                              (hazard_bus.req.rd_m2),
        .rd_w                               (hazard_bus.req.rd_w),
        .flag                               (hazard_bus.res.hazard_cause.raw_data),
        .forwarda_e                         (hazard_bus.res.forwarda_e),
        .forwardb_e                         (hazard_bus.res.forwardb_e)
    );
    
    hazard_load_use_resolver            hazard_load_use_resolver(
        .memaccess_e                        (hazard_bus.req.memaccess_e),
        .memaccess_m1                       (hazard_bus.req.memaccess_m1),
        .rd_e                               (hazard_bus.req.rd_e),
        .rd_m1                              (hazard_bus.req.rd_m1),
        .rs1_d                              (hazard_bus.req.rs1_d),
        .rs2_d                              (hazard_bus.req.rs2_d),
        .flag                               (hazard_bus.res.hazard_cause.load_use),
        .stall_f                            (stall_f),
        .stall_d                            (stall_d),
        .flush_e                            (flush_loaduse)
    );
    
    hazard_store_data_forwarder         hazard_store_data_forwarder(
        .memaccess_m1                       (hazard_bus.req.memaccess_m1),
        .regwrite_m2                        (hazard_bus.req.regwrite_m2),
        .memaccess_m2                       (hazard_bus.req.memaccess_m2),
        .rd_m2                              (hazard_bus.req.rd_m2),
        .regwrite_w                         (hazard_bus.req.regwrite_w),
        .rd_w                               (hazard_bus.req.rd_w),
        .rs2_m1                             (hazard_bus.req.rs2_m1),
        .flag                               (hazard_bus.res.hazard_cause.store_data),
        .forward_m1                         (hazard_bus.res.forward_m1)
    );
    
    hazard_branch_mispredict_resolver   hazard_branch_mispredict_resolver(
        .mispredict                         (hazard_bus.req.mispredict),
        .flag                               (hazard_bus.res.hazard_cause.branch_mispredict),
        .flush                              (flush_mispredict)
    );
    
endmodule