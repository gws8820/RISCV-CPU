timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module control_alu_decoder(
    input   aluop_t         aluop,
    input   logic           is_rtype,
    input   logic           is_alt,
    input   logic [2:0]     funct3,
    output  alucontrol_t    alucontrol
);

    always_comb begin
        unique case (aluop)
            ALUOP_ARITH: begin
                unique case(funct3)
                    3'b000:     alucontrol = (is_rtype && is_alt) ? ALU_SUB : ALU_ADD;
                    3'b001:     alucontrol = ALU_SLL;
                    3'b010:     alucontrol = ALU_SLT;
                    3'b011:     alucontrol = ALU_SLTU;
                    3'b100:     alucontrol = ALU_XOR;
                    3'b101:     alucontrol = is_alt ? ALU_SRA : ALU_SRL;
                    3'b110:     alucontrol = ALU_OR;
                    3'b111:     alucontrol = ALU_AND;
                    default:    alucontrol = ALU_ADD;
                endcase
            end
            ALUOP_MUL, ALUOP_DIV: begin
                unique case(funct3)
                    3'b000:     alucontrol = ALU_MUL;
                    3'b001:     alucontrol = ALU_MULH;
                    3'b010:     alucontrol = ALU_MULHSU;
                    3'b011:     alucontrol = ALU_MULHU;
                    3'b100:     alucontrol = ALU_DIV;
                    3'b101:     alucontrol = ALU_DIVU;
                    3'b110:     alucontrol = ALU_REM;
                    3'b111:     alucontrol = ALU_REMU;
                    default:    alucontrol = ALU_MUL;
                endcase
            end
            default: alucontrol = ALU_ADD;
        endcase
    end
endmodule
