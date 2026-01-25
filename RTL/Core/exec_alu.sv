timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module exec_alu(
    input   logic [31:0] in_a, in_b,
    input   alucontrol_t alucontrol,
    output  logic        alu_valid,
    output  logic [31:0] aluresult
);

    logic [4:0] shamt;
    assign shamt = in_b[4:0];
    
    always_comb begin
        alu_valid = 1;

        unique case (alucontrol)
            ALU_ADD:        aluresult = in_a + in_b;
            ALU_SUB:        aluresult = in_a - in_b;
            ALU_SLT:        aluresult = $signed(in_a) < $signed(in_b);
            ALU_SLTU:       aluresult = in_a < in_b;
            ALU_XOR:        aluresult = in_a ^ in_b;
            ALU_OR:         aluresult = in_a | in_b;
            ALU_AND:        aluresult = in_a & in_b;
            ALU_SLL:        aluresult = in_a << shamt;
            ALU_SRL:        aluresult = in_a >> shamt;
            ALU_SRA:        aluresult = $signed(in_a) >>> shamt;
            
            default: begin
                alu_valid   = 0;
                aluresult   = 32'b0;
            end
        endcase
    end
    
    
endmodule
