timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module single_cycle_rv32i_cpu(
    input logic rstn, clk
);
    trap_req_t trap_req;
    trap_res_t trap_res;

    //--------------IF-----------------

    // Program Counter
    pcsrc_t pcsrc;
    logic [31:0] pc_next;
    logic [31:0] pc;
    logic [31:0] aluresult;
    logic [31:0] immext;

    always_comb begin
        unique case(pcsrc)
            PC_REDIR:   pc_next = trap_res.rediraddr;
            PC_PLUS4:   pc_next = pc + 4;
            PC_PLUSIMM: pc_next = pc + immext;
            PC_ALU:     pc_next = aluresult & ~32'b1;
            default:    pc_next = pc + 4;
        endcase
    end

    program_counter program_counter (
        .rstn   (rstn),
        .clk    (clk),
        .enable (1),
        .pc_next(pc_next),
        .pc     (pc)
    );
    
    // Inst Misalign Checker
    inst_misalign_checker inst_misalign_checker (
        .pc          (pc),
        .instmisalign(trap_req.instmisalign)
    );

    
    // Instruction Memory
    inst_t inst;
    instruction_memory instruction_memory (
        .clk         (clk),
        .pc          (pc),
        .instmisalign(trap_req.instmisalign),
        .imemfault   (trap_req.imemfault),
        .inst        (inst)
    );

    //--------------ID-----------------

    // Control Unit
    control_signal_t control_signal;

    control_unit control_unit (    
        .inst       (inst),
        .nextpc_mode(control_signal.nextpc_mode),
        .cflow_mode (control_signal.cflow_mode),
        .immsrc     (control_signal.immsrc),
        .alusrc_a   (control_signal.alusrc_a),
        .alusrc_b   (control_signal.alusrc_b),
        .alucontrol (control_signal.alucontrol),
        .memaccess  (control_signal.memaccess),
        .resultsrc  (control_signal.resultsrc),
        .regwrite   (control_signal.regwrite),
        .instillegal(trap_req.instillegal)
    );

    // Register File
    logic [4:0] waddr;
    logic [4:0] raddr1;
    logic [4:0] raddr2; 
    
    assign waddr = inst.r.rd;
    assign raddr1 = inst.r.rs1;
    assign raddr2 = inst.r.rs2;

    logic [31:0] wdata;
    logic [31:0] rdata1, rdata2;
    
    regfile regfile (
        .clk     (clk),
        .regwrite(trap_req.dmemfault ? 0 : control_signal.regwrite), // PREVENT REGISTER WRITE IF DMEMFAULT
        .waddr   (waddr),
        .wdata   (wdata),
        .raddr1  (raddr1),
        .raddr2  (raddr2),
        .rdata1  (rdata1),
        .rdata2  (rdata2)
    );

    // Immediate Extender
    imm_extender imm_extender (
        .inst  (inst),
        .immsrc(control_signal.immsrc),
        .immext(immext)
    );

    //--------------EX-----------------

    // ALU Source Selector
    logic [31:0] in_a, in_b;
    
    always_comb begin
        unique case(control_signal.alusrc_a)
            SRCA_REG:   in_a = rdata1;
            SRCA_PC:    in_a = pc;
            SRCA_ZERO:  in_a = 32'b0;
            default:    in_a = rdata1;
        endcase

        unique case(control_signal.alusrc_b)
            SRCB_REG:   in_b = rdata2;
            SRCB_IMM:   in_b = immext;
        endcase
    end

    // ALU
    alu alu (
        .in_a      (in_a),
        .in_b      (in_b),
        .alucontrol(control_signal.alucontrol),
        .aluresult (aluresult)
    );
    
    // LSU Misalign Checker
    lsu_misalign_checker lsu_misalign_checker (
        .aluresult   (aluresult),
        .memaccess   (control_signal.memaccess),
        .mask_mode   (inst.i.funct3),
        .datamisalign(trap_req.datamisalign)
    );
    
    // Branch Unit
    branch_unit branch_unit (
        .nextpc_mode(control_signal.nextpc_mode),
        .branch_mode(control_signal.funct3),
        .in_a       (in_a),
        .in_b       (in_b),
        .redirflag  (trap_res.redirflag),
        .pcsrc      (pcsrc)
    );

    //--------------MEM-----------------

    // Load Store Unit
    logic [31:0] memresult;
    
    load_store_unit load_store_unit (
        .clk      (clk),
        .addr     (aluresult),
        .data     (rdata2),
        .memaccess(trap_req.datamisalign ? MEM_DISABLED : control_signal.memaccess), // PREVENT MEMORY ACCESS IF MISALIGNED
        .mask_mode(control_signal.funct3),
        .rdata_ext(memresult),
        .dmemfault(trap_req.dmemfault)
    );
    
    // Trap Unit
    trap_pkt_t trap_pkt;
    logic [31:0] mtvec, mepc;

    single_cycle_trap_pkt_gen single_cycle_trap_pkt_gen (
        .pc          (pc),
        .dataaddr    (aluresult),
        .inst        (inst),
        .memaccess   (control_signal.memaccess),
        .instillegal (trap_req.instillegal),
        .instmisalign(trap_req.instmisalign),
        .datamisalign(trap_req.datamisalign),
        .imemfault   (trap_req.imemfault),
        .dmemfault   (trap_req.dmemfault),
        .cflow_mode  (control_signal.cflow_mode),
        .trap_pkt    (trap_pkt)
    );
    
    trap_unit trap_unit (
        .trap_pkt(trap_pkt),
        .trap_res(trap_res),
        .mtvec_i (mtvec),
        .mepc_i  (mepc)
    );
    
    csr_unit csr_unit (
        .rstn    (rstn),
        .clk     (clk),
        .trap_pkt(trap_pkt),
        .mtvec_o (mtvec),
        .mepc_o  (mepc)
    );

    //--------------WB-----------------

    // Result Selector
    always_comb begin
        unique case(control_signal.resultsrc)
            RESULT_ALU:     wdata = aluresult;
            RESULT_MEM:     wdata = memresult;
            RESULT_PCPLUS4: wdata = pc + 4;
            default:        wdata = aluresult;
        endcase
    end
        
endmodule