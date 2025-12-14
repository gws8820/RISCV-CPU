timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module alu(
    input   logic [31:0] in_a, in_b,
    input   alucontrol_t alucontrol,
    output  logic [31:0] aluresult
);

    localparam bit ENABLE_RV32M = 0;

    logic [4:0] shamt;
    assign shamt    = in_b[4:0];
    
    logic [63:0] mul, mulsu, mulu;
    always_comb begin
        if (ENABLE_RV32M) begin
            mul     = $signed(in_a)     * $signed(in_b);
            mulsu   = $signed(in_a)     * $unsigned(in_b);
            mulu    = $unsigned(in_a)   * $unsigned(in_b);
        end
        else begin
            mul     = '0;
            mulsu   = '0;
            mulu    = '0;
        end
    end
    
    logic overflow_cond;
    assign overflow_cond = (in_a == 32'h8000_0000) && (in_b == -1);
    
    always_comb begin
        unique case (alucontrol)
            ALU_ADD:    aluresult = in_a + in_b;
            ALU_SUB:    aluresult = in_a - in_b;
            ALU_SLT:    aluresult = $signed(in_a) < $signed(in_b);
            ALU_SLTU:   aluresult = in_a < in_b;
            ALU_XOR:    aluresult = in_a ^ in_b;
            ALU_OR:     aluresult = in_a | in_b;
            ALU_AND:    aluresult = in_a & in_b;
            ALU_SLL:    aluresult = in_a << shamt;
            ALU_SRL:    aluresult = in_a >> shamt;
            ALU_SRA:    aluresult = $signed(in_a) >>> shamt;
            
            ALU_MUL:    aluresult = ENABLE_RV32M ? mul[31:0]     : 32'b0;
            ALU_MULH:   aluresult = ENABLE_RV32M ? mul[63:32]    : 32'b0;
            ALU_MULHSU: aluresult = ENABLE_RV32M ? mulsu[63:32]  : 32'b0;
            ALU_MULHU:  aluresult = ENABLE_RV32M ? mulu[63:32]   : 32'b0;
            
            ALU_DIV:    begin
                if (!ENABLE_RV32M)          aluresult = 32'b0;
                
                else if (in_b == 32'b0)     aluresult = 32'hFFFF_FFFF;
                else if (overflow_cond)     aluresult = 32'h8000_0000;
                else                        aluresult = $signed(in_a) / $signed(in_b);
            end
            ALU_DIVU:   begin
                if (!ENABLE_RV32M)          aluresult = 32'b0;
                
                else if (in_b == 32'b0)     aluresult = 32'hFFFF_FFFF;
                else                        aluresult = in_a / in_b;
            end
            ALU_REM:    begin
                if (!ENABLE_RV32M)          aluresult = 32'b0;
                
                else if (in_b == 32'b0)     aluresult = $signed(in_a);
                else if (overflow_cond)     aluresult = 32'b0;
                else                        aluresult = $signed(in_a) % $signed(in_b);
            end
            ALU_REMU:   begin
                if (!ENABLE_RV32M)          aluresult = 32'b0;
                
                else if (in_b == 32'b0)     aluresult = in_a;
                else                        aluresult = in_a % in_b;
            end
            default:                        aluresult = 32'b0;
        endcase
    end
    
    
endmodule
