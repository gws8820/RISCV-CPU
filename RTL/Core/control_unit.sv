timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module control_unit (
    input   inst_t          inst,
    output  cflow_mode_t    cflow_mode,
    output  sysop_mode_t    sysop_mode,
    output  funct3_t        funct3,
    output  csr_req_t       csr_req,
    output  logic           fencei,
    output  immsrc_t        immsrc,
    output  alusrca_t       alusrc_a,
    output  alusrcb_t       alusrc_b,
    output  alucontrol_t    alucontrol,
    output  aluop_t         aluop,
    output  memaccess_t     memaccess,
    output  resultsrc_t     resultsrc,
    output  logic           regwrite,
    output  logic           instillegal
);
    
    logic is_rtype, is_alt;
    
    logic [6:0] funct7;
    assign funct3 = inst.r.funct3;
    assign funct7 = inst.r.funct7;
    
    logic illegal_op, illegal_csr;
    assign instillegal = illegal_op || illegal_csr;
    
    csr_req_t csr_req_reg;
    always_comb begin
        csr_req.valid      = csr_req_reg.valid && !instillegal;
        csr_req.use_imm    = csr_req_reg.use_imm;
        csr_req.csr_mode   = csr_req_reg.csr_mode;
        csr_req.csr_target = csr_req_reg.csr_target;
    end
    
    control_main_decoder main_decoder (
        .opcode             (inst.i.opcode),
        .funct3             (funct3),
        .funct7             (funct7),
        .imm                (inst.i.imm),
        .cflow_mode         (cflow_mode),
        .sysop_mode         (sysop_mode),
        .fencei             (fencei),
        .immsrc             (immsrc),
        .alusrc_a           (alusrc_a),
        .alusrc_b           (alusrc_b),
        .aluop              (aluop),
        .memaccess          (memaccess),
        .resultsrc          (resultsrc),
        .regwrite           (regwrite),
        .is_rtype           (is_rtype),
        .is_alt             (is_alt),
        .illegal_op         (illegal_op)
    );
    
    control_alu_decoder alu_decoder (
        .aluop              (aluop),
        .is_rtype           (is_rtype),
        .is_alt             (is_alt),
        .funct3             (funct3),
        .alucontrol         (alucontrol)
    );
    
    control_csr_decoder csr_decoder (
        .opcode             (inst.i.opcode),
        .wtarget            (inst.i.rs1),
        .csr_mode           (funct3.csr_mode),
        .csr_target         (inst.i.imm),
        .csr_req            (csr_req_reg),
        .illegal_csr        (illegal_csr)
    );
    
endmodule