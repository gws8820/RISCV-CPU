timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module main_decoder(
    input   opcode_t        opcode,
    input   logic [2:0]     funct3,
    input   logic [6:0]     funct7,
    input   logic [11:0]    imm,
    output  nextpc_mode_t   nextpc_mode,
    output  cflow_mode_t    cflow_mode,
    output  logic           fencei,
    output  immsrc_t        immsrc,
    output  alusrca_t       alusrc_a,
    output  alusrcb_t       alusrc_b,
    output  aluop_t         aluop,
    output  memaccess_t     memaccess,
    output  resultsrc_t     resultsrc,
    output  logic           regwrite,
    output  logic           is_rtype,
    output  logic           is_alt,
    output  logic           illegal_op
);

    csr_mode_t csr_mode;
    assign csr_mode = csr_mode_t'(funct3);
    
    always_comb begin
        nextpc_mode         = NEXTPC_PLUS4;
        cflow_mode          = CFLOW_NORMAL;
        fencei              = 0;
        immsrc              = IMM_I;
        alusrc_a            = SRCA_REG;
        alusrc_b            = SRCB_REG;
        aluop               = ALUOP_ADD;
        memaccess           = MEM_DISABLED;
        resultsrc           = RESULT_ALU;
        regwrite            = 0;
        is_rtype            = 0;
        is_alt              = 0;
        illegal_op          = 0;
        
        unique case(opcode)
            OP_OP: begin
                unique case (funct7)
                    FUNCT7_STD: begin
                        aluop   = ALUOP_ARITH;
                        is_alt  = 0;
                    end
                    FUNCT7_ALT: begin
                        aluop   = ALUOP_ARITH;
                        is_alt  = 1;
                    end
                    FUNCT7_MUL: begin
                        aluop   = ALUOP_MUL;
                        is_alt  = 0;
                    end
                    default:    illegal_op = 1;
                endcase
                
                nextpc_mode = NEXTPC_PLUS4;
                cflow_mode  = CFLOW_NORMAL;
                immsrc      = IMM_I;
                alusrc_a    = SRCA_REG;
                alusrc_b    = SRCB_REG;
                memaccess   = MEM_DISABLED;
                resultsrc   = RESULT_ALU;
                regwrite    = 1;
                is_rtype    = 1;
            end
            OP_OPIMM: begin
                unique case (funct7)
                    FUNCT7_STD: is_alt = 0;
                    FUNCT7_ALT: is_alt = 1;
                    default:    is_alt = 0;
                endcase
                
                nextpc_mode = NEXTPC_PLUS4;
                cflow_mode  = CFLOW_NORMAL;
                immsrc      = IMM_I;
                alusrc_a    = SRCA_REG;
                alusrc_b    = SRCB_IMM;
                aluop       = ALUOP_ARITH;
                memaccess   = MEM_DISABLED;
                resultsrc   = RESULT_ALU;
                regwrite    = 1;
            end
            OP_LOAD: begin
                nextpc_mode = NEXTPC_PLUS4;
                cflow_mode  = CFLOW_NORMAL;
                immsrc      = IMM_I;
                alusrc_a    = SRCA_REG;
                alusrc_b    = SRCB_IMM;
                aluop       = ALUOP_ADD;
                memaccess   = MEM_READ;
                resultsrc   = RESULT_MEM;
                regwrite    = 1;
            end
            OP_STORE: begin
                nextpc_mode = NEXTPC_PLUS4;
                cflow_mode  = CFLOW_NORMAL;
                immsrc      = IMM_S;
                alusrc_a    = SRCA_REG;
                alusrc_b    = SRCB_IMM;
                aluop       = ALUOP_ADD;
                memaccess   = MEM_WRITE;
                resultsrc   = RESULT_ALU;
                regwrite    = 0;
            end
            OP_LUI: begin
                nextpc_mode = NEXTPC_PLUS4;
                cflow_mode  = CFLOW_NORMAL;
                immsrc      = IMM_U;
                alusrc_a    = SRCA_ZERO;
                alusrc_b    = SRCB_IMM;
                aluop       = ALUOP_ADD;
                memaccess   = MEM_DISABLED;
                resultsrc   = RESULT_ALU;
                regwrite    = 1;
            end
            OP_AUIPC: begin
                nextpc_mode = NEXTPC_PLUS4;
                cflow_mode  = CFLOW_NORMAL;
                immsrc      = IMM_U;
                alusrc_a    = SRCA_PC;
                alusrc_b    = SRCB_IMM;
                aluop       = ALUOP_ADD;
                memaccess   = MEM_DISABLED;
                resultsrc   = RESULT_ALU;
                regwrite    = 1;
            end
            OP_BRANCH: begin
                nextpc_mode = NEXTPC_BRANCH;
                cflow_mode  = CFLOW_NORMAL;
                immsrc      = IMM_B;
                alusrc_a    = SRCA_REG;
                alusrc_b    = SRCB_REG;
                aluop       = ALUOP_ARITH;
                memaccess   = MEM_DISABLED;
                resultsrc   = RESULT_ALU;
                regwrite    = 0;
            end
            OP_JALR: begin
                nextpc_mode = NEXTPC_JALR;
                cflow_mode  = CFLOW_NORMAL;
                immsrc      = IMM_I;
                alusrc_a    = SRCA_REG;
                alusrc_b    = SRCB_IMM;
                aluop       = ALUOP_ADD;
                memaccess   = MEM_DISABLED;
                resultsrc   = RESULT_PCPLUS4;
                regwrite    = 1;
            end
            OP_JAL: begin
                nextpc_mode = NEXTPC_JAL;
                cflow_mode  = CFLOW_NORMAL;
                immsrc      = IMM_J;
                alusrc_a    = SRCA_REG;
                alusrc_b    = SRCB_IMM;
                aluop       = ALUOP_ADD;
                memaccess   = MEM_DISABLED;
                resultsrc   = RESULT_PCPLUS4;
                regwrite    = 1;
            end
            OP_MISC_MEM: begin
                fencei = (funct3 == FUNCT3_FENCEI);
            end
            OP_SYSTEM: begin
                if (csr_mode == CSR_NOP) begin
                    unique case (imm)
                        12'h000: cflow_mode = CFLOW_ECALL;
                        12'h001: cflow_mode = CFLOW_EBREAK;
                        12'h302: cflow_mode = CFLOW_MRET;
                        12'h105: ; // WFI Instruction (Hint)
                        default: illegal_op = 1;
                    endcase
                end
                else begin // Zicsr Extension
                    nextpc_mode = NEXTPC_PLUS4;
                    cflow_mode  = CFLOW_NORMAL;
                    immsrc      = IMM_Z;
                    alusrc_a    = SRCA_REG;
                    alusrc_b    = SRCB_REG;
                    aluop       = ALUOP_ADD;
                    memaccess   = MEM_DISABLED;
                    resultsrc   = RESULT_CSR;
                    regwrite    = 1;
                end
            end
            default: illegal_op = 1;
        endcase
    end
endmodule