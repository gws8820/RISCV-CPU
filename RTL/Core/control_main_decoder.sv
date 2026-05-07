timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module control_main_decoder (
    input   opcode_t                        opcode,
    input   logic [2:0]                     funct3,
    input   logic [6:0]                     funct7,
    input   logic [11:0]                    imm,
    output  cflow_mode_t                    cflow_mode,
    output  sysop_mode_t                    sysop_mode,
    output  logic                           fencei,
    output  logic                           use_rs1,
    output  logic                           use_rs2,
    output  immsrc_t                        immsrc,
    output  alusrca_t                       alusrc_a,
    output  alusrcb_t                       alusrc_b,
    output  aluop_t                         aluop,
    output  memaccess_t                     memaccess,
    output  resultsrc_t                     resultsrc,
    output  logic                           regwrite,
    output  logic                           is_rtype,
    output  logic                           is_alt,
    output  logic                           illegal_op
);

    csr_mode_t                              csr_mode;
    csr_mode_t                              csr_mode_from_funct3;
    logic                                   csr_mode_valid;

    always_comb begin
        csr_mode_from_funct3                = csr_mode_t'(funct3);
        csr_mode                            = CSR_NOP;
        csr_mode_valid                      = 1;

        case (csr_mode_from_funct3)
            CSR_NOP:    csr_mode            = CSR_NOP;
            CSR_RW:     csr_mode            = CSR_RW;
            CSR_RS:     csr_mode            = CSR_RS;
            CSR_RC:     csr_mode            = CSR_RC;
            CSR_RWI:    csr_mode            = CSR_RWI;
            CSR_RSI:    csr_mode            = CSR_RSI;
            CSR_RCI:    csr_mode            = CSR_RCI;
            default: begin
                csr_mode                    = CSR_NOP;
                csr_mode_valid              = 0;
            end
        endcase
    end

    always_comb begin
        cflow_mode                          = CFLOW_PCPLUS4;
        sysop_mode                          = SYSOP_NORMAL;
        fencei                              = 0;
        use_rs1                             = 0;
        use_rs2                             = 0;
        immsrc                              = IMM_I;
        alusrc_a                            = SRCA_REG;
        alusrc_b                            = SRCB_REG;
        aluop                               = ALUOP_ADD;
        memaccess                           = MEM_DISABLED;
        resultsrc                           = RESULT_ALU;
        regwrite                            = 0;
        is_rtype                            = 0;
        is_alt                              = 0;
        illegal_op                          = 0;

        case (opcode)
            OP_OP: begin
                illegal_op                  = !(funct7 inside {FUNCT7_STD, FUNCT7_ALT, FUNCT7_MUL});

                case (funct7)
                    FUNCT7_STD: begin
                        aluop               = ALUOP_ARITH;
                        is_alt              = 0;
                    end
                    FUNCT7_ALT: begin
                        aluop               = ALUOP_ARITH;
                        is_alt              = 1;
                    end
                    FUNCT7_MUL: begin
                        if (funct3[2] == 0) begin   // MUL
                            aluop           = ALUOP_MUL;
                            is_alt          = 0;
                        end
                        else begin                  // DIV, REM
                            aluop           = ALUOP_DIV;
                            is_alt          = 0;
                        end
                    end
                    default: begin
                        illegal_op          = 1;
                    end
                endcase

                cflow_mode                  = CFLOW_PCPLUS4;
                sysop_mode                  = SYSOP_NORMAL;
                use_rs1                     = 1;
                use_rs2                     = 1;
                immsrc                      = IMM_I;
                alusrc_a                    = SRCA_REG;
                alusrc_b                    = SRCB_REG;
                memaccess                   = MEM_DISABLED;
                resultsrc                   = RESULT_ALU;
                regwrite                    = 1;
                is_rtype                    = 1;
            end
            OP_OPIMM: begin
                is_alt                      = (funct7 == FUNCT7_ALT);

                cflow_mode                  = CFLOW_PCPLUS4;
                sysop_mode                  = SYSOP_NORMAL;
                use_rs1                     = 1;
                use_rs2                     = 0;
                immsrc                      = IMM_I;
                alusrc_a                    = SRCA_REG;
                alusrc_b                    = SRCB_IMM;
                aluop                       = ALUOP_ARITH;
                memaccess                   = MEM_DISABLED;
                resultsrc                   = RESULT_ALU;
                regwrite                    = 1;
            end
            OP_LOAD: begin
                cflow_mode                  = CFLOW_PCPLUS4;
                sysop_mode                  = SYSOP_NORMAL;
                use_rs1                     = 1;
                use_rs2                     = 0;
                immsrc                      = IMM_I;
                alusrc_a                    = SRCA_REG;
                alusrc_b                    = SRCB_IMM;
                aluop                       = ALUOP_ADD;
                memaccess                   = MEM_READ;
                resultsrc                   = RESULT_MEM;
                regwrite                    = 1;
            end
            OP_STORE: begin
                cflow_mode                  = CFLOW_PCPLUS4;
                sysop_mode                  = SYSOP_NORMAL;
                use_rs1                     = 1;
                use_rs2                     = 1;
                immsrc                      = IMM_S;
                alusrc_a                    = SRCA_REG;
                alusrc_b                    = SRCB_IMM;
                aluop                       = ALUOP_ADD;
                memaccess                   = MEM_WRITE;
                resultsrc                   = RESULT_ALU;
                regwrite                    = 0;
            end
            OP_LUI: begin
                cflow_mode                  = CFLOW_PCPLUS4;
                sysop_mode                  = SYSOP_NORMAL;
                use_rs1                     = 0;
                use_rs2                     = 0;
                immsrc                      = IMM_U;
                alusrc_a                    = SRCA_ZERO;
                alusrc_b                    = SRCB_IMM;
                aluop                       = ALUOP_ADD;
                memaccess                   = MEM_DISABLED;
                resultsrc                   = RESULT_ALU;
                regwrite                    = 1;
            end
            OP_AUIPC: begin
                cflow_mode                  = CFLOW_PCPLUS4;
                sysop_mode                  = SYSOP_NORMAL;
                use_rs1                     = 0;
                use_rs2                     = 0;
                immsrc                      = IMM_U;
                alusrc_a                    = SRCA_PC;
                alusrc_b                    = SRCB_IMM;
                aluop                       = ALUOP_ADD;
                memaccess                   = MEM_DISABLED;
                resultsrc                   = RESULT_ALU;
                regwrite                    = 1;
            end
            OP_BRANCH: begin
                cflow_mode                  = CFLOW_BRANCH;
                sysop_mode                  = SYSOP_NORMAL;
                use_rs1                     = 1;
                use_rs2                     = 1;
                immsrc                      = IMM_B;
                alusrc_a                    = SRCA_PC;
                alusrc_b                    = SRCB_IMM;
                aluop                       = ALUOP_ADD;
                memaccess                   = MEM_DISABLED;
                resultsrc                   = RESULT_ALU;
                regwrite                    = 0;
            end
            OP_JALR: begin
                cflow_mode                  = CFLOW_JALR;
                sysop_mode                  = SYSOP_NORMAL;
                use_rs1                     = 1;
                use_rs2                     = 0;
                immsrc                      = IMM_I;
                alusrc_a                    = SRCA_REG;
                alusrc_b                    = SRCB_IMM;
                aluop                       = ALUOP_ADD;
                memaccess                   = MEM_DISABLED;
                resultsrc                   = RESULT_PCPLUS4;
                regwrite                    = 1;
            end
            OP_JAL: begin
                cflow_mode                  = CFLOW_JAL;
                sysop_mode                  = SYSOP_NORMAL;
                use_rs1                     = 0;
                use_rs2                     = 0;
                immsrc                      = IMM_J;
                alusrc_a                    = SRCA_PC;
                alusrc_b                    = SRCB_IMM;
                aluop                       = ALUOP_ADD;
                memaccess                   = MEM_DISABLED;
                resultsrc                   = RESULT_PCPLUS4;
                regwrite                    = 1;
            end
            OP_MISC_MEM: begin
                fencei                      = (funct3 == FUNCT3_FENCEI);
            end
            OP_SYSTEM: begin
                if (!csr_mode_valid) begin
                    illegal_op              = 1;
                end
                else if (csr_mode == CSR_NOP) begin
                    illegal_op              = !(imm inside {12'h000, 12'h001, 12'h302, 12'h105});

                    case (imm)
                        12'h000:    sysop_mode      = SYSOP_ECALL;
                        12'h001:    sysop_mode      = SYSOP_EBREAK;
                        12'h302:    sysop_mode      = SYSOP_MRET;
                        12'h105:    ; // WFI Instruction (Hint)
                        default:    illegal_op      = 1;
                    endcase
                end
                else begin // Zicsr Extension
                    cflow_mode              = CFLOW_PCPLUS4;
                    sysop_mode              = SYSOP_NORMAL;
                    use_rs1                 = !(csr_mode inside {CSR_RWI, CSR_RSI, CSR_RCI});
                    use_rs2                 = 0;
                    immsrc                  = IMM_Z;
                    alusrc_a                = SRCA_REG;
                    alusrc_b                = SRCB_REG;
                    aluop                   = ALUOP_ADD;
                    memaccess               = MEM_DISABLED;
                    resultsrc               = RESULT_CSR;
                    regwrite                = 1;
                end
            end
            default: begin
                illegal_op                  = 1;
            end
        endcase
    end

endmodule
