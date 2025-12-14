timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_unit (
    hazard_interface.completer      hazard_bus
);
    logic flush_d_sd, flush_e_lu;
    
    always_comb begin
        hazard_bus.res.flush_d  = hazard_bus.req.flushflag || flush_d_sd;
        hazard_bus.res.flush_e  = hazard_bus.req.flushflag || flush_e_lu;
        hazard_bus.res.flush_m  = hazard_bus.req.flushflag;
    end
    
    raw_data_forwarder raw_data_forwarder(
        .regwrite_e                 (hazard_bus.req.regwrite_e),
        .regwrite_m                 (hazard_bus.req.regwrite_m),
        .regwrite_w                 (hazard_bus.req.regwrite_w),
        .rs1_d                      (hazard_bus.req.rs1_d),
        .rs2_d                      (hazard_bus.req.rs2_d),
        .rs1_e                      (hazard_bus.req.rs1_e),
        .rs2_e                      (hazard_bus.req.rs2_e),
        .rd_e                       (hazard_bus.req.rd_e),
        .rd_m                       (hazard_bus.req.rd_m),
        .rd_w                       (hazard_bus.req.rd_w),
        .flag_d                     (hazard_bus.res.hazard_cause.raw_data_id),
        .flag_e                     (hazard_bus.res.hazard_cause.raw_data_ex),
        .forwarda_d                 (hazard_bus.res.forwarda_d),
        .forwardb_d                 (hazard_bus.res.forwardb_d),
        .forwarda_e                 (hazard_bus.res.forwarda_e),
        .forwardb_e                 (hazard_bus.res.forwardb_e)
    );
    
    load_use_resolver load_use_resolver(
        .memaccess_e                (hazard_bus.req.memaccess_e),
        .memaccess_m                (hazard_bus.req.memaccess_m),
        .cflow_mode                 (hazard_bus.req.cflow_mode),
        .rd_e                       (hazard_bus.req.rd_e),
        .rd_m                       (hazard_bus.req.rd_m),
        .rs1_d                      (hazard_bus.req.rs1_d),
        .rs2_d                      (hazard_bus.req.rs2_d),
        .flag                       (hazard_bus.res.hazard_cause.load_use),
        .stall_f                    (hazard_bus.res.stall_f),
        .stall_d                    (hazard_bus.res.stall_d),
        .flush_e                    (flush_e_lu)
    );
    
    store_data_forwarder store_data_forwarder(
        .memaccess_m                (hazard_bus.req.memaccess_m),
        .regwrite_w                 (hazard_bus.req.regwrite_w),
        .rd_w                       (hazard_bus.req.rd_w),
        .rs2_m                      (hazard_bus.req.rs2_m),
        .flag                       (hazard_bus.res.hazard_cause.store_data),
        .forward_mem                (hazard_bus.res.forward_mem)
    );
    
    branch_mispredict_resolver branch_mispredict_resolver(
        .mispredict                 (hazard_bus.req.mispredict),
        .flag                       (hazard_bus.res.hazard_cause.branch_mispredict),
        .flush_d                    (flush_d_sd)
    );
    
endmodule