timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module riscv_cpu_core (
    input   logic                   start,
    input   logic                   clk,

    memory_init_interface.sink      rom_init,
    mmio_out_interface.source       mmio_out,
    mmio_in_interface.sink          mmio_in
);

    // -------- Backward Signals ---------

    logic [31:0]                    result_m1;
    logic [31:0]                    result_m2;
    logic                           regwrite_w;
    logic [4:0]                     rd_w;
    logic [31:0]                    result_w;
    logic                           instret_w;
    
    // ---------- Hazard Unit ------------
    
    hazard_interface                hazard_bus();
    
    hazard_unit hazard_unit (
        .start                      (start),
        .clk                        (clk),
        .hazard_bus                 (hazard_bus)
    );

    always_comb begin
        hazard_bus.req.flushflag    = trap_bus.res.flushflag || control_bus_m1.fencei;
        hazard_bus.req.mispredict   = mispredict;
        hazard_bus.req.ex_fire      = ex_fire;
        hazard_bus.req.aluop_e      = control_bus_e.aluop;
        hazard_bus.req.use_rs1_d    = control_bus_d.use_rs1;
        hazard_bus.req.use_rs2_d    = control_bus_d.use_rs2;
        hazard_bus.req.rs1_d        = rs1_d;
        hazard_bus.req.rs1_e        = rs1_e;
        hazard_bus.req.rs2_d        = rs2_d;
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
    
    logic [31:0]                    mtvec, mepc;
    trap_interface                  trap_bus();

    trap_unit trap_unit (
        .trap_bus                   (trap_bus),
        .mtvec_i                    (mtvec),
        .mepc_i                     (mepc)
    );
    
    always_comb begin
        trap_bus.req                = trap_req_m1;
    end
    
    // ----------- CSR Unit --------------
    
    csr_interface                   csr_bus();
    csr_unit csr_unit (
        .start                      (start),
        .clk                        (clk),
        .instret                    (instret_w),
        .trap                       (trap_bus.req),
        .csr_bus                    (csr_bus),
        .mtvec_o                    (mtvec),
        .mepc_o                     (mepc)
    );
    
    always_comb begin
        csr_bus.req                 = control_bus_e.csr_req;
        csr_bus.wdata               = csr_wdata_e;
    end
    
    // -------- Branch Predictor ---------

    logic [31:0]                    pc_f;
    logic [31:0]                    pc_e, pc_e_reg;
    logic [31:0]                    pcplus4_e, pcplus4_e_reg;

    logic [31:0]                    pc_pred;
    logic [31:0]                    pc_jump;
    
    cflow_mode_t                    cflow_mode_reg;
    cflow_hint_t                    cflow_hint_reg;
    logic                           pred_taken;
    logic                           cflow_taken;
    logic                           mispredict;
    
    always_ff@(posedge clk) begin
        if (!start) begin
            pc_e_reg                <= 32'b0;
            pcplus4_e_reg           <= 32'b0;
        end
        else begin
            pc_e_reg                <= pc_e;
            pcplus4_e_reg           <= pcplus4_e;
        end
    end
    
    branch_predictor branch_predictor (
        .start                      (start),
        .clk                        (clk),
        
        .pc_f                       (pc_f),
        .pred_taken                 (pred_taken),
        .pred_target                (pc_pred),
        
        .pc_e                       (pc_e_reg),
        .cflow_mode                 (cflow_mode_reg),
        .cflow_hint                 (cflow_hint_reg),
        .cflow_taken                (cflow_taken),
        .cflow_target               (pc_jump)
    );

    // ------------ Memory Blocks --------

    inst_t                          rom_fetch_inst;
    logic [31:0]                    rom_fetch_addr;
    logic                           rom_fetch_access_fault;

    logic                           rom_load_enable;
    logic [31:0]                    rom_load_addr;
    logic [31:0]                    rom_load_data;
    
    memaccess_t                     ram_access;
    logic [31:0]                    ram_addr;
    logic [3:0]                     ram_wstrb;
    logic [31:0]                    ram_write_data;
    logic [31:0]                    ram_read_data;

    memory_rom memory_rom (
        .start                      (start),
        .clk                        (clk),

        .fetch_addr                 (rom_fetch_addr),
        .fetch_access_fault         (rom_fetch_access_fault),
        .fetch_inst                 (rom_fetch_inst),

        .load_enable                (rom_load_enable),
        .load_addr                  (rom_load_addr),
        .load_data                  (rom_load_data),

        .init                       (rom_init)
    );

    memory_ram memory_ram (
        .clk                        (clk),
        .access                     (ram_access),
        .addr                       (ram_addr),
        .wstrb                      (ram_wstrb),
        .write_data                 (ram_write_data),
        .read_data                  (ram_read_data)
    );

    // ------------ IF Stage -------------

    logic [31:0]                    pcplus4_f;
    trap_req_t                      trap_req_f;
    
    stage_if stage_if (
        .start                      (start),
        .clk                        (clk),

        .pc_pred                    (pc_pred),
        .pc_jump                    (pc_jump),
        .pc_return                  (pcplus4_e_reg),
        .mispredict                 (mispredict),
        .cflow_taken                (cflow_taken),
        .pred_taken                 (pred_taken),
        
        .pc_f                       (pc_f),
        .pcplus4_f                  (pcplus4_f),
        .fetch_addr                 (rom_fetch_addr),
        
        .fetch_access_fault         (rom_fetch_access_fault),

        .trap_res                   (trap_bus.res),
        .trap_req_f                 (trap_req_f),
        .hazard_res                 (hazard_bus.res)
    );

    // ------------ ID Stage -------------

    control_bus_t                   control_bus_d;
    cflow_hint_t                    cflow_hint_d;
    logic [31:0]                    pc_d;
    logic [31:0]                    pcplus4_d;
    logic [31:0]                    pc_pred_d;
    logic                           pred_taken_d;

    logic [4:0]                     rs1_d, rs2_d, rd_d;
    logic [31:0]                    rdata1_d, rdata2_d;
    logic [31:0]                    immext_d;
    trap_req_t                      trap_req_d;

    stage_id stage_id (
        .start                      (start),
        .clk                        (clk),

        .pc_f                       (pc_f),
        .pcplus4_f                  (pcplus4_f),
        .pc_pred_f                  (pc_pred),
        .pred_taken_f               (pred_taken),
        .fetch_inst                 (rom_fetch_inst),
        
        .regwrite_w                 (regwrite_w),
        .rd_w                       (rd_w),
        .result_w                   (result_w),

        .control_bus_d              (control_bus_d),
        .cflow_hint_d               (cflow_hint_d),
        .pc_d                       (pc_d),
        .pcplus4_d                  (pcplus4_d),
        .pc_pred_d                  (pc_pred_d),
        .pred_taken_d               (pred_taken_d),
        .rs1_d                      (rs1_d),
        .rs2_d                      (rs2_d),
        .rd_d                       (rd_d),
        .rdata1_d                   (rdata1_d),
        .rdata2_d                   (rdata2_d),
        .immext_d                   (immext_d),

        .trap_req_f                 (trap_req_f),
        .trap_req_d                 (trap_req_d),
        .hazard_res                 (hazard_bus.res)
    );

    // ------------ EX Stage -------------

    control_bus_t                   control_bus_e;
    logic                           ex_fire;
    logic [4:0]                     rs1_e, rs2_e, rd_e;
    logic                           alu_valid, mul_valid, div_valid;
    logic [31:0]                    aluresult_e, mulresult_e, divresult_e;
    logic [31:0]                    storedata_e;
    logic [31:0]                    csr_wdata_e;
    trap_req_t                      trap_req_e;

    stage_ex stage_ex (
        .start                      (start),
        .clk                        (clk),

        .control_bus_d              (control_bus_d),
        .cflow_hint_d               (cflow_hint_d),
        .pc_d                       (pc_d),
        .pcplus4_d                  (pcplus4_d),
        .pc_pred_d                  (pc_pred_d),
        .pred_taken_d               (pred_taken_d),
        .rs1_d                      (rs1_d),
        .rs2_d                      (rs2_d),
        .rd_d                       (rd_d),
        .rdata1_d                   (rdata1_d),
        .rdata2_d                   (rdata2_d),
        .immext_d                   (immext_d),

        .result_m1                  (result_m1),
        .result_m2                  (result_m2),
        .result_w                   (result_w),

        .control_bus_e              (control_bus_e),
        .pc_e                       (pc_e),
        .pcplus4_e                  (pcplus4_e),
        .rs1_e                      (rs1_e),
        .rs2_e                      (rs2_e),
        .rd_e                       (rd_e),

        .alu_valid                  (alu_valid),
        .mul_valid                  (mul_valid),
        .div_valid                  (div_valid),
        .aluresult_e                (aluresult_e),
        .mulresult_e                (mulresult_e),
        .divresult_e                (divresult_e),

        .storedata_e                (storedata_e),
        .csr_wdata_e                (csr_wdata_e),

        .pc_jump                    (pc_jump),
        .cflow_mode_reg             (cflow_mode_reg),
        .cflow_hint_reg             (cflow_hint_reg),
        .cflow_taken                (cflow_taken),
        .mispredict                 (mispredict),
        .ex_fire                    (ex_fire),

        .trap_req_d                 (trap_req_d),
        .trap_req_e                 (trap_req_e),
        .hazard_res                 (hazard_bus.res)
    );

    // ------------ MEM1 Stage -----------
    
    control_bus_t                   control_bus_m1;
    logic [4:0]                     rs2_m1;
    logic [4:0]                     rd_m1;
    logic [31:0]                    csr_wdata_m1;
    loadsrc_t                       load_source_m1;
    logic [1:0]                     byte_offset_m1;
    trap_req_t                      trap_req_m1;

    stage_mem1 stage_mem1 (
        .start                      (start),
        .clk                        (clk),

        .control_bus_e              (control_bus_e),
        .pc_e                       (pc_e),
        .pcplus4_e                  (pcplus4_e),
        .rs2_e                      (rs2_e),
        .rd_e                       (rd_e),

        .alu_valid                  (alu_valid),
        .mul_valid                  (mul_valid),
        .div_valid                  (div_valid),
        .aluresult_e                (aluresult_e),
        .mulresult_e                (mulresult_e),
        .divresult_e                (divresult_e),

        .storedata_e                (storedata_e),
        .csr_wdata_e                (csr_wdata_e),

        .result_w                   (result_w),

        .control_bus_m1             (control_bus_m1),
        .rd_m1                      (rd_m1),
        .rs2_m1                     (rs2_m1),
        .csr_wdata_m1               (csr_wdata_m1),
        .load_source_m1             (load_source_m1),
        .byte_offset_m1             (byte_offset_m1),
        .result_m1                  (result_m1),

        .rom_load_enable            (rom_load_enable),
        .rom_load_addr              (rom_load_addr),

        .ram_access                 (ram_access),
        .ram_addr                   (ram_addr),
        .ram_wstrb                  (ram_wstrb),
        .ram_write_data             (ram_write_data),

        .trap_req_e                 (trap_req_e),
        .trap_req_m1                (trap_req_m1),
        .csr_result                 (csr_bus.rdata),
        .hazard_res                 (hazard_bus.res),

        .mmio_out                   (mmio_out),
        .mmio_in                    (mmio_in)
    );

    // ------------ MEM2 Stage -----------

    control_bus_t                   control_bus_m2;
    logic [4:0]                     rd_m2;
    logic [31:0]                    memresult_m2;

    stage_mem2 stage_mem2 (
        .start                      (start),
        .clk                        (clk),

        .control_bus_m1             (control_bus_m1),
        .rd_m1                      (rd_m1),
        .load_source_m1             (load_source_m1),
        .byte_offset_m1             (byte_offset_m1),
        .result_m1                  (result_m1),
        .ram_read_data              (ram_read_data),
        .rom_load_data              (rom_load_data),
        .mmio_in_valid              (mmio_in.valid),
        .mmio_in_data               (mmio_in.data),

        .control_bus_m2             (control_bus_m2),
        .rd_m2                      (rd_m2),
        .memresult_m2               (memresult_m2),
        .result_m2                  (result_m2),

        .hazard_res                 (hazard_bus.res)
    );

    // ------------ WB Stage -------------

    stage_wb stage_wb (
        .start                      (start),
        .clk                        (clk),

        .control_bus_m2             (control_bus_m2),
        .rd_m2                      (rd_m2),
        .memresult_m2               (memresult_m2),
        .result_m2                  (result_m2),

        .regwrite_w                 (regwrite_w),
        .rd_w                       (rd_w),
        .result_w                   (result_w),
        .instret_w                  (instret_w)
    );

endmodule
