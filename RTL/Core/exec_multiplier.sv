timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module exec_multiplier (
    input   logic           start, clk,
    input   logic           flush,
    input   logic           ex_fire,
    input   aluop_t         aluop,
    input   alucontrol_t    alucontrol,
    input   logic [31:0]    in_a, in_b,
    output  logic           mul_valid,
    output  logic [31:0]    mulresult
);

    logic mul_busy;
    (* use_dsp = "yes" *) logic [63:0] mul, mulsu, mulu;
    
    always_ff@(posedge clk) begin
        if (!start) begin
            mul_valid           <= 0;
            mul_busy            <= 0;
            mul                 <= 64'b0;
            mulsu               <= 64'b0;
            mulu                <= 64'b0;
            mulresult           <= 32'b0;
        end
        else begin
            priority if (flush) begin
                mul_valid       <= 0;
                mul_busy        <= 0;
                mul             <= 64'b0;
                mulsu           <= 64'b0;
                mulu            <= 64'b0;
                mulresult       <= 32'b0;
            end
            else if (ex_fire && (aluop == ALUOP_MUL)) begin
                mul_valid       <= 0;
                mul_busy        <= 1;
                
                mul             <= $signed(in_a)    *   $signed(in_b);
                mulsu           <= $signed(in_a)    *   $unsigned(in_b);
                mulu            <= $unsigned(in_a)  *   $unsigned(in_b);
            end
            else if (mul_busy) begin
                mul_valid       <= 1;
                mul_busy        <= 0;
                
                unique case (alucontrol)
                    ALU_MUL:    mulresult <= mul[31:0];
                    ALU_MULH:   mulresult <= mul[63:32];
                    ALU_MULHSU: mulresult <= mulsu[63:32];
                    ALU_MULHU:  mulresult <= mulu[63:32];
                    default:    mulresult <= 32'd0;
                endcase
            end
            else begin
                mul_valid       <= 0;
            end
        end
    end

endmodule