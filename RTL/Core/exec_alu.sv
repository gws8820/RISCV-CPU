timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module exec_alu(
    input   logic [31:0]    in_a, in_b,
    input   alucontrol_t    alucontrol,
    output  logic           alu_valid,
    output  logic [31:0]    aluresult
);

    logic [4:0] shamt;
    assign shamt = in_b[4:0];
    
    always_comb begin
        alu_valid = 0;
        aluresult = 32'b0;

        case (alucontrol)
            ALU_ADD: begin
                alu_valid   = 1;
                aluresult   = in_a + in_b;
            end
            ALU_SUB: begin
                alu_valid   = 1;
                aluresult   = in_a - in_b;
            end
            ALU_SLT: begin
                alu_valid   = 1;
                aluresult   = {31'b0, ($signed(in_a) < $signed(in_b))};
            end
            ALU_SLTU: begin
                alu_valid   = 1;
                aluresult   = {31'b0, (in_a < in_b)};
            end
            ALU_XOR: begin
                alu_valid   = 1;
                aluresult   = in_a ^ in_b;
            end
            ALU_OR: begin
                alu_valid   = 1;
                aluresult   = in_a | in_b;
            end
            ALU_AND: begin
                alu_valid   = 1;
                aluresult   = in_a & in_b;
            end
            ALU_SLL: begin
                alu_valid   = 1;
                aluresult   = in_a << shamt;
            end
            ALU_SRL: begin
                alu_valid   = 1;
                aluresult   = in_a >> shamt;
            end
            ALU_SRA: begin
                alu_valid   = 1;
                aluresult   = $unsigned($signed(in_a) >>> shamt);
            end
            ALU_MUL, ALU_MULH, ALU_MULHSU, ALU_MULHU,
            ALU_DIV, ALU_DIVU, ALU_REM, ALU_REMU: begin
                alu_valid   = 0;
                aluresult   = 32'b0;
            end
            default: begin
                alu_valid   = 0;
                aluresult   = 32'b0;
            end
        endcase
    end
    
    
endmodule
