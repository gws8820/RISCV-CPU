timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module alu_decoder(
    input   aluop_t         aluop,
    input   logic           is_rtype,
    input   logic [2:0]     funct3,
    input   logic           funct7_5,
    output  alucontrol_t    alucontrol
);

    always_comb begin
        if(aluop == ALUOP_ARITH) begin
            unique case(funct3)
                3'b000:     alucontrol = (is_rtype && funct7_5) ? ALU_SUB : ALU_ADD;
                3'b001:     alucontrol = ALU_SLL;
                3'b010:     alucontrol = ALU_SLT;
                3'b011:     alucontrol = ALU_SLTU;
                3'b100:     alucontrol = ALU_XOR;
                3'b101:     alucontrol = funct7_5 ? ALU_SRA : ALU_SRL;
                3'b110:     alucontrol = ALU_OR;
                3'b111:     alucontrol = ALU_AND;
                default:    alucontrol = ALU_ADD;
            endcase
        end
        else alucontrol = ALU_ADD;
    end
endmodule
