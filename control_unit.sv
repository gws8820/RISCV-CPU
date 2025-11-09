timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module control_unit (
    input   inst_t          inst,
    output  nextpc_mode_t   nextpc_mode,
    output  cflow_mode_t    cflow_mode,
    output  funct3_t        funct3,
    output  csr_pkt_t       csr_pkt,
    output  logic           fencei,
    output  immsrc_t        immsrc,
    output  alusrca_t       alusrc_a,
    output  alusrcb_t       alusrc_b,
    output  alucontrol_t    alucontrol,
    output  memaccess_t     memaccess,
    output  resultsrc_t     resultsrc,
    output  logic           regwrite,
    output  logic           instillegal
);
    
    aluop_t aluop;
    logic is_rtype;
    
    assign funct3 = inst.i.funct3;
    
    logic illegal_op, illegal_csr;
    assign instillegal = illegal_op || illegal_csr;
    
    csr_pkt_t csr_pkt_reg;
    always_comb begin
        csr_pkt.valid      = csr_pkt_reg.valid && !instillegal;
        csr_pkt.use_imm    = csr_pkt_reg.use_imm;
        csr_pkt.csr_mode   = csr_pkt_reg.csr_mode;
        csr_pkt.csr_target = csr_pkt_reg.csr_target;
    end
    
    main_decoder main_decoder (
        .opcode     (inst.i.opcode),
        .funct3     (funct3),
        .imm        (inst.i.imm),
        .nextpc_mode(nextpc_mode),
        .cflow_mode (cflow_mode),
        .fencei     (fencei),
        .immsrc     (immsrc),
        .alusrc_a   (alusrc_a),
        .alusrc_b   (alusrc_b),
        .aluop      (aluop),
        .memaccess  (memaccess),
        .resultsrc  (resultsrc),
        .regwrite   (regwrite),
        .is_rtype   (is_rtype),
        .illegal_op (illegal_op)
    );
    
    alu_decoder alu_decoder (
        .aluop      (aluop),
        .is_rtype   (is_rtype),
        .funct3     (funct3),
        .funct7_5   (inst.r.funct7[5]),
        .alucontrol (alucontrol)
    );
    
    csr_decoder csr_decoder (
        .opcode     (inst.i.opcode),
        .wtarget    (inst.i.rs1),
        .csr_mode   (funct3),
        .csr_target (inst.i.imm),
        .csr_pkt    (csr_pkt_reg),
        .illegal_csr(illegal_csr)
    );
    
endmodule