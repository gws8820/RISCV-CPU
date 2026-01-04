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
    
    trap_req_t              trap_req_m1;
    logic [31:0]            csr_wdata_m1;
    logic [31:0]            result_m1;

    logic [31:0]            result_m2;

    control_signal_t        control_signal_w;
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
        trap_bus.req        = trap_req_m1;

        csr_bus.req         = control_signal_m1.csr_req;
        csr_bus.wdata       = csr_wdata_m1;
        csr_bus.trap        = trap_req_m1;
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

    logic [31:0]            pc_f;
    logic [31:0]            pc_e, pc_e_sync;
    logic [31:0]            pcplus4_e, pcplus4_e_sync;

    logic [31:0]            pc_pred;
    logic [31:0]            pc_jump;
    
    logic                   pred_taken;
    logic                   cflow_valid;
    logic                   cflow_taken;
    logic                   mispredict;
    
    always_ff@(posedge clk) begin
        if (!start) begin
            pc_e_sync <= 32'b0;
            pcplus4_e_sync <= 32'b0;
        end
        else begin
            pc_e_sync <= pc_e;
            pcplus4_e_sync <= pcplus4_e;
        end
    end
    
    branch_predictor branch_predictor (
        .clk                (clk),
        
        .pc_f               (pc_f),
        .pred_taken         (pred_taken),
        .pred_target        (pc_pred),
        
        .pc_e               (pc_e_sync),
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
        .pc_return          (pcplus4_e_sync),
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

        .result_m1          (result_m1),
        .result_m2          (result_m2),
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

    // ------------ MEM1 Stage -----------
    
    control_signal_t        control_signal_m1;
    logic [31:0]            pc_m1;
    logic [31:0]            pcplus4_m1;
    logic [4:0]             rd_m1;
    logic [31:0]            loaddata_m1;
    logic [1:0]             byte_offset_m1;
    
    stage_mem1 stage_mem1 (
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

        .control_signal_m1  (control_signal_m1),
        .pc_m1              (pc_m1),
        .pcplus4_m1         (pcplus4_m1),
        .rd_m1              (rd_m1),
        .csr_wdata_m1       (csr_wdata_m1),
        .loaddata_m1        (loaddata_m1),
        .byte_offset_m1     (byte_offset_m1),
        .result_m1          (result_m1),

        .trap_res           (trap_bus.res),
        .trap_req_e         (trap_req_e),
        .trap_req_m1        (trap_req_m1),
        
        .csr_result         (csr_bus.rdata),

        .hazard_bus         (hazard_bus),
        
        .print_en           (print_en),
        .print_data         (print_data)
    );

    // ------------ MEM2 Stage -----------

    control_signal_t        control_signal_m2;
    logic [4:0]             rd_m2;
    logic [31:0]            memresult_m2;

    stage_mem2 stage_mem2 (
        .start              (start),
        .clk                (clk),

        .control_signal_m1  (control_signal_m1),
        .pc_m1              (pc_m1),
        .pcplus4_m1         (pcplus4_m1),
        .rd_m1              (rd_m1),
        .loaddata_m1        (loaddata_m1),
        .byte_offset_m1     (byte_offset_m1),
        .result_m1          (result_m1),

        .control_signal_m2  (control_signal_m2),
        .rd_m2              (rd_m2),
        .memresult_m2       (memresult_m2),
        .result_m2          (result_m2),

        .hazard_bus         (hazard_bus)
    );
    
    // ------------ WB Stage -------------
    
    stage_wb stage_wb (
        .start              (start),
        .clk                (clk),

        .control_signal_m2  (control_signal_m2),
        .rd_m2              (rd_m2),
        .memresult_m2       (memresult_m2),
        .result_m2          (result_m2),

        .control_signal_w   (control_signal_w),
        .rd_w               (rd_w),
        .result_w           (result_w),

        .hazard_bus         (hazard_bus)
    );
        
endmodule