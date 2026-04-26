timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_unit (
    input   logic                           start, clk,
    hazard_interface.sink                   hazard_bus
);
    logic                                   flush_mispredict, flush_loaduse, flush_muldiv;
    logic                                   stall_muldiv, stall_loaduse;
    (* MAX_FANOUT = 64 *) logic             flush_d, flush_e, flush_e_sidefx, flush_m1, flush_m2;
    (* MAX_FANOUT = 64 *) logic             stall_f, stall_d, stall_e;

    logic flush_d_reg;
    always_ff@(posedge clk) begin
        if (!start)                         flush_d_reg <= 0;
        else                                flush_d_reg <= flush_d;
    end

    always_comb begin
        flush_d                             = (hazard_bus.req.flushflag || flush_mispredict);
        flush_e                             = (hazard_bus.req.flushflag || flush_mispredict || flush_loaduse);
        flush_e_sidefx                      = (hazard_bus.req.flushflag || flush_mispredict);
        flush_m1                            = (hazard_bus.req.flushflag || flush_mispredict || flush_muldiv);
        flush_m2                            = (hazard_bus.req.flushflag);

        stall_f                             = !flush_d  && (stall_muldiv || stall_loaduse);
        stall_d                             = !flush_d  && (stall_muldiv || stall_loaduse);
        stall_e                             = !flush_e  && stall_muldiv;

        hazard_bus.res.flush_d              = flush_d;
        hazard_bus.res.flush_d_inst         = flush_d || flush_d_reg;
        hazard_bus.res.flush_e              = flush_e;
        hazard_bus.res.flush_e_sidefx       = flush_e_sidefx;
        hazard_bus.res.flush_m1             = flush_m1;
        hazard_bus.res.flush_m2             = flush_m2;
        hazard_bus.res.stall_f              = stall_f;
        hazard_bus.res.stall_d              = stall_d;
        hazard_bus.res.stall_e              = stall_e;
        
        hazard_bus.res.hazard_cause.flushflag   = hazard_bus.req.flushflag;
    
    end
    
    hazard_raw_data_forwarder           raw_data_forwarder (
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
    
    hazard_store_data_forwarder         store_data_forwarder (
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
    
    hazard_load_use_resolver            load_use_resolver (
        .memaccess_e                        (hazard_bus.req.memaccess_e),
        .memaccess_m1                       (hazard_bus.req.memaccess_m1),
        .rd_e                               (hazard_bus.req.rd_e),
        .rd_m1                              (hazard_bus.req.rd_m1),
        .use_rs1_d                          (hazard_bus.req.use_rs1_d),
        .use_rs2_d                          (hazard_bus.req.use_rs2_d),
        .rs1_d                              (hazard_bus.req.rs1_d),
        .rs2_d                              (hazard_bus.req.rs2_d),
        .flag                               (hazard_bus.res.hazard_cause.load_use),
        .stall                              (stall_loaduse),
        .flush                              (flush_loaduse)
    );
    
    hazard_muldiv_stall_resolver        muldiv_stall_resolver (
        .start                              (start),
        .clk                                (clk),
        .ex_fire                            (hazard_bus.req.ex_fire),
        .aluop_e                            (hazard_bus.req.aluop_e),
        .flush_e                            (flush_e),
        .flag                               (hazard_bus.res.hazard_cause.muldiv_stall),
        .stall                              (stall_muldiv),
        .flush                              (flush_muldiv)
    );
    
    hazard_branch_mispredict_resolver   branch_mispredict_resolver (
        .mispredict                         (hazard_bus.req.mispredict),
        .flag                               (hazard_bus.res.hazard_cause.branch_mispredict),
        .flush                              (flush_mispredict)
    );
    
endmodule
