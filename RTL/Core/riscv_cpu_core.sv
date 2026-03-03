timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module riscv_cpu_core (
    input   logic           start,
    input   logic           clk,
    
    input   logic           prog_en,
    input   logic [31:0]    prog_addr,
    input   logic [31:0]    prog_data,

    output  logic           print_en,
    output  logic [31:0]    print_data
);
    
    // ---------- Hazard Unit ------------
    
    hazard_interface        hazard_bus();
    
    hazard_unit hazard_unit (
        .start              (start),
        .clk                (clk),
        .hazard_bus         (hazard_bus)
    );

    always_comb begin
        hazard_bus.req.flushflag    = trap_bus.res.flushflag || control_bus_m1.fencei;
        hazard_bus.req.mispredict   = mispredict;
        hazard_bus.req.ex_fire      = ex_fire;
        hazard_bus.req.aluop_e      = control_bus_e.aluop;
        hazard_bus.req.rs1_d        = inst_f.r.rs1;
        hazard_bus.req.rs1_e        = rs1_e;
        hazard_bus.req.rs2_d        = inst_f.r.rs2;
        hazard_bus.req.rs2_e        = rs2_e;
        hazard_bus.req.rs2_m1       = rs2_m1;
        hazard_bus.req.rd_e         = rd_e;
        hazard_bus.req.rd_m1        = rd_m1;
        hazard_bus.req.rd_m2        = rd_m2;
        hazard_bus.req.rd_w         = rd_w;
        hazard_bus.req.regwrite_m1  = control_bus_m1.regwrite;
        hazard_bus.req.regwrite_m2  = control_bus_m2.regwrite;
        hazard_bus.req.regwrite_w   = regwrite_w;
        hazard_bus.req.memaccess_e  = control_bus_e.memaccess;
        hazard_bus.req.memaccess_m1 = control_bus_m1.memaccess;
        hazard_bus.req.memaccess_m2 = control_bus_m2.memaccess;
    end

    // ----------- Trap Unit -------------
    
    logic [31:0]            mtvec, mepc;
    
    trap_interface          trap_bus();
    (* mark_debug = "true" *) trap_flag_t trap_flag;
    
    trap_unit trap_unit (
        .trap_bus           (trap_bus),
        .mtvec_i            (mtvec),
        .mepc_i             (mepc)
    );
    
    always_comb begin
        trap_bus.req        = trap_req_m1;
    end
    
    // ----------- CSR Unit --------------
    
    csr_interface           csr_bus();
    csr_unit csr_unit (
        .start              (start),
        .clk                (clk),
        .instret            (instret_w),
        .trap               (trap_bus.req),
        .csr_bus            (csr_bus),
        .mtvec_o            (mtvec),
        .mepc_o             (mepc)
    );
    
    always_comb begin
        csr_bus.req         = control_bus_e.csr_req;
        csr_bus.wdata       = csr_wdata_e;
    end
    
    // -------- Branch Predictor ---------

    logic                   ex_fire;

    logic [31:0]            pc_f;
    logic [31:0]            pc_e, pc_e_reg;
    logic [31:0]            pcplus4_e, pcplus4_e_reg;

    logic [31:0]            pc_pred;
    logic [31:0]            pc_jump;
    
    logic                   pred_taken_reg;
    cflow_mode_t            cflow_mode_reg;
    cflow_hint_t            cflow_hint;
    logic                   cflow_taken;
    logic                   mispredict;
    
    always_ff@(posedge clk) begin
        if (!start) begin
            pc_e_reg        <= 32'b0;
            pcplus4_e_reg   <= 32'b0;
        end
        else begin
            pc_e_reg        <= pc_e;
            pcplus4_e_reg   <= pcplus4_e;
        end
    end
    
    branch_predictor branch_predictor (
        .start              (start),
        .clk                (clk),
        
        .pc_f               (pc_f),
        .pred_taken         (pred_taken),
        .pred_target        (pc_pred),
        
        .pc_e               (pc_e_reg),
        .cflow_mode         (cflow_mode_reg),
        .cflow_hint         (cflow_hint_reg),
        .cflow_taken        (cflow_taken),
        .cflow_target       (pc_jump)
    );

    // ------------ IF Stage -------------

    logic [31:0]            pcplus4_f;
    inst_t                  inst_f;

    trap_req_t              trap_req_f;
    
    stage_if stage_if (
        .start              (start),
        .clk                (clk),

        .pc_pred            (pc_pred),
        .pc_jump            (pc_jump),
        .pc_return          (pcplus4_e_reg),
        .mispredict         (mispredict),
        .cflow_taken        (cflow_taken),
        .pred_taken         (pred_taken),
        
        .pc_f               (pc_f),
        .pcplus4_f          (pcplus4_f),
        .inst_f             (inst_f),

        .trap_res           (trap_bus.res),
        .trap_req_f         (trap_req_f),
        .instmisalign       (trap_flag.instmisalign),
        .imemfault          (trap_flag.imemfault),
        .hazard_res         (hazard_bus.res),
        
        .prog_en            (prog_en),
        .prog_addr          (prog_addr),
        .prog_data          (prog_data)
    );

    // ------------ ID Stage -------------

    control_bus_t           control_bus_d;
    cflow_hint_t            cflow_hint_d;
    logic [31:0]            pc_d;
    logic [31:0]            pcplus4_d;
    logic [31:0]            pc_pred_d;
    logic                   pred_taken_d;

    logic [4:0]             rs1_d, rs2_d, rd_d;
    logic [31:0]            rdata1_d, rdata2_d;
    logic [31:0]            immext_d;
    
    trap_req_t              trap_req_d;

    stage_id stage_id (
        .start              (start),
        .clk                (clk),

        .pc_f               (pc_f),
        .pcplus4_f          (pcplus4_f),
        .pc_pred_f          (pc_pred),
        .pred_taken_f       (pred_taken),
        .inst_f             (inst_f),
        
        .regwrite_w         (regwrite_w),
        .rd_w               (rd_w),
        .result_w           (result_w),

        .control_bus_d      (control_bus_d),
        .cflow_hint_d       (cflow_hint_d),
        .pc_d               (pc_d),
        .pcplus4_d          (pcplus4_d),
        .pc_pred_d          (pc_pred_d),
        .pred_taken_d       (pred_taken_d),
        .rs1_d              (rs1_d),
        .rs2_d              (rs2_d),
        .rd_d               (rd_d),
        .rdata1_d           (rdata1_d),
        .rdata2_d           (rdata2_d),
        .immext_d           (immext_d),

        .trap_req_f         (trap_req_f),
        .trap_req_d         (trap_req_d),
        .instillegal        (trap_flag.instillegal),
        .hazard_res         (hazard_bus.res)
    );

    // ------------ EX Stage -------------

    control_bus_t           control_bus_e;
    logic [4:0]             rs1_e, rs2_e, rd_e;
    logic                   alu_valid, mul_valid, div_valid;
    logic [31:0]            aluresult_e, mulresult_e, divresult_e;
    logic [31:0]            storedata_e;
    logic [31:0]            csr_wdata_e;

    trap_req_t              trap_req_e;

    stage_ex stage_ex (
        .start              (start),
        .clk                (clk),

        .control_bus_d      (control_bus_d),
        .cflow_hint_d       (cflow_hint_d),
        .pc_d               (pc_d),
        .pcplus4_d          (pcplus4_d),
        .pc_pred_d          (pc_pred_d),
        .pred_taken_d       (pred_taken_d),
        .rs1_d              (rs1_d),
        .rs2_d              (rs2_d),
        .rd_d               (rd_d),
        .rdata1_d           (rdata1_d),
        .rdata2_d           (rdata2_d),
        .immext_d           (immext_d),

        .result_m1          (result_m1),
        .result_m2          (result_m2),
        .result_w           (result_w),

        .control_bus_e      (control_bus_e),
        .pc_e               (pc_e),
        .pcplus4_e          (pcplus4_e),
        .rs1_e              (rs1_e),
        .rs2_e              (rs2_e),
        .rd_e               (rd_e),

        .alu_valid          (alu_valid),
        .mul_valid          (mul_valid),
        .div_valid          (div_valid),
        .aluresult_e        (aluresult_e),
        .mulresult_e        (mulresult_e),
        .divresult_e        (divresult_e),

        .storedata_e        (storedata_e),
        .csr_wdata_e        (csr_wdata_e),

        .pc_jump            (pc_jump),
        .cflow_mode_reg     (cflow_mode_reg),
        .cflow_hint_reg     (cflow_hint_reg),
        .cflow_taken        (cflow_taken),
        .mispredict         (mispredict),
        .ex_fire            (ex_fire),

        .trap_req_d         (trap_req_d),
        .trap_req_e         (trap_req_e),
        .hazard_res         (hazard_bus.res)
    );

    // ------------ MEM1 Stage -----------
    
    control_bus_t           control_bus_m1;
    logic [4:0]             rs2_m1;
    logic [4:0]             rd_m1;
    logic [31:0]            csr_wdata_m1;
    logic [31:0]            loaddata_m1;
    logic [1:0]             byte_offset_m1;
    logic [31:0]            result_m1;
    
    trap_req_t              trap_req_m1;

    stage_mem1 stage_mem1 (
        .start              (start),
        .clk                (clk),

        .control_bus_e      (control_bus_e),
        .pc_e               (pc_e),
        .pcplus4_e          (pcplus4_e),
        .rs2_e              (rs2_e),
        .rd_e               (rd_e),

        .alu_valid          (alu_valid),
        .mul_valid          (mul_valid),
        .div_valid          (div_valid),
        .aluresult_e        (aluresult_e),
        .mulresult_e        (mulresult_e),
        .divresult_e        (divresult_e),
        
        .storedata_e        (storedata_e),
        .csr_wdata_e        (csr_wdata_e),

        .result_w           (result_w),

        .control_bus_m1     (control_bus_m1),
        .rd_m1              (rd_m1),
        .rs2_m1             (rs2_m1),
        .csr_wdata_m1       (csr_wdata_m1),
        .loaddata_m1        (loaddata_m1),
        .byte_offset_m1     (byte_offset_m1),
        .result_m1          (result_m1),

        .trap_res           (trap_bus.res),
        .trap_req_e         (trap_req_e),
        .trap_req_m1        (trap_req_m1),
        .datamisalign       (trap_flag.datamisalign),
        .dmemfault          (trap_flag.dmemfault),
        .csr_result         (csr_bus.rdata),
        .hazard_res         (hazard_bus.res),
        
        .print_en           (print_en),
        .print_data         (print_data)
    );

    // ------------ MEM2 Stage -----------

    control_bus_t           control_bus_m2;
    logic [4:0]             rd_m2;
    logic [31:0]            memresult_m2;
    logic [31:0]            result_m2;

    stage_mem2 stage_mem2 (
        .start              (start),
        .clk                (clk),

        .control_bus_m1     (control_bus_m1),
        .rd_m1              (rd_m1),
        .loaddata_m1        (loaddata_m1),
        .byte_offset_m1     (byte_offset_m1),
        .result_m1          (result_m1),

        .control_bus_m2     (control_bus_m2),
        .rd_m2              (rd_m2),
        .memresult_m2       (memresult_m2),
        .result_m2          (result_m2),

        .hazard_res         (hazard_bus.res)
    );

    // ------------ WB Stage -------------

    logic                   regwrite_w;
    logic [4:0]             rd_w;
    logic [31:0]            result_w;
    logic                   instret_w;

    stage_wb stage_wb (
        .start              (start),
        .clk                (clk),

        .control_bus_m2     (control_bus_m2),
        .rd_m2              (rd_m2),
        .memresult_m2       (memresult_m2),
        .result_m2          (result_m2),

        .regwrite_w         (regwrite_w),
        .rd_w               (rd_w),
        .result_w           (result_w),
        .instret_w          (instret_w)
    );

endmodule