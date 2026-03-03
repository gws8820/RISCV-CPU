timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module exec_multiplier (
    input   logic               start, clk,
    input   logic               flush,
    input   logic               ex_fire,
    input   aluop_t             aluop,
    input   alucontrol_t        alucontrol,
    input   logic [31:0]        in_a, in_b,
    output  logic               mul_valid,
    output  logic [31:0]        mulresult
);

    logic                       mul_busy;
    logic                       dsp_ready;

    alucontrol_t                alucontrol_reg;
    logic [31:0]                in_a_reg, in_b_reg;
    logic [32:0]                op_a_reg, op_b_reg;

    logic [32:0]                op_a, op_b;
    (* use_dsp = "yes" *)       logic [65:0] mulproduct;
    assign mulproduct           = $signed(op_a_reg) * $signed(op_b_reg);

    always_comb begin
        unique case (alucontrol_reg)
            ALU_MUL: begin
                op_a = {1'b0,           in_a_reg};
                op_b = {1'b0,           in_b_reg};
            end
            ALU_MULH: begin
                op_a = {in_a_reg[31],   in_a_reg};
                op_b = {in_b_reg[31],   in_b_reg};
            end
            ALU_MULHSU: begin
                op_a = {in_a_reg[31],   in_a_reg};
                op_b = {1'b0,           in_b_reg};
            end
            ALU_MULHU: begin
                op_a = {1'b0,           in_a_reg};
                op_b = {1'b0,           in_b_reg};
            end
            default: begin
                op_a = 33'd0;
                op_b = 33'd0;
            end
        endcase
    end

    always_ff@(posedge clk) begin
        if (!start) begin
            mul_valid           <= 0;
            mul_busy            <= 0;
            dsp_ready           <= 0;
        end
        else begin
            priority if (flush) begin
                mul_valid       <= 0;
                mul_busy        <= 0;
                dsp_ready       <= 0;
            end
            else if (ex_fire && (aluop == ALUOP_MUL) && !mul_busy) begin
                mul_valid       <= 0;
                mul_busy        <= 1;
                dsp_ready       <= 0;
                in_a_reg        <= in_a;
                in_b_reg        <= in_b;
                alucontrol_reg  <= alucontrol;
            end
            else if (mul_busy) begin
                if (!dsp_ready) begin
                    op_a_reg    <= op_a;
                    op_b_reg    <= op_b;
                    dsp_ready   <= 1;
                end
                else begin
                    mul_valid   <= 1;
                    mul_busy    <= 0;
                    dsp_ready   <= 0;

                    unique case (alucontrol_reg)
                        ALU_MUL:    mulresult <= mulproduct[31:0];
                        ALU_MULH:   mulresult <= mulproduct[63:32];
                        ALU_MULHSU: mulresult <= mulproduct[63:32];
                        ALU_MULHU:  mulresult <= mulproduct[63:32];
                        default:    mulresult <= 32'd0;
                    endcase
                end
            end
            else begin
                mul_valid       <= 0;
            end
        end
    end

endmodule
