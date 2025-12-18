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
    
    // --------- Backward Signals --------
    
    trap_req_t              trap_req_m;
    logic [31:0]            csr_wdata_m;
    logic [31:0]            result_m;

    control_signal_t        control_signal_w;
    logic                   kill_w;
    logic [4:0]             rd_w;
    logic [31:0]            result_w;
    
    // ---------- Hazard Unit ------------
    
    hazard_interface        hazard_bus();
    
    hazard_unit hazard_unit (
        .hazard_bus         (hazard_bus)
    );

    // Trap / CSR
    logic [31:0] mtvec, mepc;

    trap_interface          trap_bus();
    csr_interface           csr_bus();

    always_comb begin
        trap_bus.req        = trap_req_m;

        csr_bus.req         = control_signal_m.csr_req;
        csr_bus.wdata       = csr_wdata_m;
        csr_bus.trap        = trap_req_m;
    end

    // ----------- Trap Unit -------------
    
    trap_unit trap_unit (
        .trap_bus           (trap_bus),
        .mtvec_i            (mtvec),
        .mepc_i             (mepc)
    );
    
    // ----------- CSR Unit --------------
    
    csr_unit csr_unit (
        .start              (start),
        .clk                (clk),
        .csr_bus            (csr_bus),
        .mtvec_o            (mtvec),
        .mepc_o             (mepc)
    );
    
    // -------- Branch Predictor ---------
    
    logic [31:0]            pc_f, pc_e;
    logic [31:0]            pcplus4_e;  // PC_RETURN
    
    logic [31:0]            pc_pred;
    logic [31:0]            pc_jump;
    
    logic                   pred_taken;
    logic                   cflow_valid;
    logic                   cflow_taken;
    logic                   mispredict;
    
    branch_predictor branch_predictor (
        .start              (start),
        .clk                (clk),
        
        .pc_f               (pc_f),
        .pred_taken         (pred_taken),
        .pred_target        (pc_pred),
        
        .pc_e               (pc_e),
        .cflow_valid        (cflow_valid),
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
        .pc_return          (pcplus4_e),
        .mispredict         (mispredict),
        .cflow_taken        (cflow_taken),
        .pred_taken         (pred_taken),
        
        .pc_f               (pc_f),
        .pcplus4_f          (pcplus4_f),
        .inst_f             (inst_f),

        .trap_res           (trap_bus.res),
        .trap_req_f         (trap_req_f),
        .hazard_bus         (hazard_bus),
        
        .prog_en            (prog_en),
        .prog_addr          (prog_addr),
        .prog_data          (prog_data)
    );

    // ------------ ID Stage -------------

    control_signal_t        control_signal_d;
    logic [31:0]            pc_d;
    logic [31:0]            pcplus4_d;
    logic [31:0]            pc_pred_d;
    logic                   pred_taken_d;
    inst_t                  inst_d;

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
        
        .control_signal_w   (control_signal_w),
        .kill_w             (kill_w),
        .rd_w               (rd_w),
        .result_w           (result_w),

        .control_signal_d   (control_signal_d),
        .pc_d               (pc_d),
        .pcplus4_d          (pcplus4_d),
        .pc_pred_d          (pc_pred_d),
        .pred_taken_d       (pred_taken_d),
        .inst_d             (inst_d),
        .rs1_d              (rs1_d),
        .rs2_d              (rs2_d),
        .rd_d               (rd_d),
        .rdata1_d           (rdata1_d),
        .rdata2_d           (rdata2_d),
        .immext_d           (immext_d),

        .trap_req_f         (trap_req_f),
        .trap_req_d         (trap_req_d),
        .hazard_bus         (hazard_bus)
    );

    // ------------ EX Stage -------------

    control_signal_t        control_signal_e;
    logic [31:0]            immext_e;
    logic [4:0]             rs1_e, rs2_e, rd_e;
    logic [31:0]            rdata1_e, rdata2_e;
    logic [31:0]            in_a, in_b;
    logic [31:0]            aluresult_e;
    logic [31:0]            storedata_e;
    logic [31:0]            csr_wdata_e;

    trap_req_t              trap_req_e;

    stage_ex stage_ex (
        .start              (start),
        .clk                (clk),

        .pc_d               (pc_d),
        .pcplus4_d          (pcplus4_d),
        .pc_pred_d          (pc_pred_d),
        .pred_taken_d       (pred_taken_d),
        .inst_d             (inst_d),

        .control_signal_d   (control_signal_d),
        .rs1_d              (rs1_d),
        .rs2_d              (rs2_d),
        .rd_d               (rd_d),
        .rdata1_d           (rdata1_d),
        .rdata2_d           (rdata2_d),
        .immext_d           (immext_d),

        .result_m           (result_m),
        .result_w           (result_w),

        .control_signal_e   (control_signal_e),
        .pc_e               (pc_e),
        .pcplus4_e          (pcplus4_e),
        .immext_e           (immext_e),
        .rs1_e              (rs1_e),
        .rs2_e              (rs2_e),
        .rd_e               (rd_e),
        .rdata1_e           (rdata1_e),
        .rdata2_e           (rdata2_e),
        .in_a               (in_a),
        .in_b               (in_b),
        .aluresult_e        (aluresult_e),
        .storedata_e        (storedata_e),
        .csr_wdata_e        (csr_wdata_e),

        .pc_jump            (pc_jump),
        .cflow_valid        (cflow_valid),
        .cflow_taken        (cflow_taken),
        .mispredict         (mispredict),

        .trap_req_d         (trap_req_d),
        .trap_req_e         (trap_req_e),
        .hazard_bus         (hazard_bus)
    );

    // ------------ MEM Stage ------------
    
    control_signal_t        control_signal_m;
    logic [31:0]            pc_m;
    logic [31:0]            pcplus4_m;
    logic [4:0]             rs2_m, rd_m;
    logic [31:0]            memresult_m;
    
    stage_mem stage_mem (
        .start              (start),
        .clk                (clk),

        .control_signal_e   (control_signal_e),
        .pc_e               (pc_e),
        .pcplus4_e          (pcplus4_e),
        .rs2_e              (rs2_e),
        .rd_e               (rd_e),
        .aluresult_e        (aluresult_e),
        .storedata_e        (storedata_e),
        .csr_wdata_e        (csr_wdata_e),

        .result_w           (result_w),

        .control_signal_m   (control_signal_m),
        .pc_m               (pc_m),
        .pcplus4_m          (pcplus4_m),
        .rs2_m              (rs2_m),
        .rd_m               (rd_m),
        .csr_wdata_m        (csr_wdata_m),
        .memresult_m        (memresult_m),
        .result_m           (result_m),

        .trap_req_e         (trap_req_e),
        .trap_req_m         (trap_req_m),
        .trap_res           (trap_bus.res),
        
        .csr_result         (csr_bus.rdata),

        .hazard_bus         (hazard_bus),
        
        .print_en           (print_en),
        .print_data         (print_data)
    );
    
    // ------------ WB Stage -------------
    
    stage_wb stage_wb (
        .start              (start),
        .clk                (clk),

        .control_signal_m   (control_signal_m),
        .rd_m               (rd_m),
        .memresult_m        (memresult_m),
        .result_m           (result_m),

        .control_signal_w   (control_signal_w),
        .kill_w             (kill_w),
        .rd_w               (rd_w),
        .result_w           (result_w),

        .trap_req_m         (trap_req_m),
        .hazard_bus         (hazard_bus)
    );
        
endmodule