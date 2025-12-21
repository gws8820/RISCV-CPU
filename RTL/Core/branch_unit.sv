timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_unit (
    input   logic           start, clk,
    input   cflow_mode_t    cflow_mode_reg,
    input   branch_mode_t   branch_mode_reg,
    input   logic [31:0]    in_a_reg, in_b_reg,
    input   logic           pred_taken_reg,
    input   logic [31:0]    pc_pred_reg,
    input   logic [31:0]    aluresult_reg,
    output  logic [31:0]    pc_jump,
    output  logic           cflow_valid,
    output  logic           cflow_taken,
    output  logic           mispredict
);

    // -----------------------------
    //       Input Registering
    // -----------------------------

    cflow_mode_t            cflow_mode;
    branch_mode_t           branch_mode;
    logic [31:0]            in_a, in_b;
    logic                   pred_taken;
    logic [31:0]            pc_pred;
    logic [31:0]            aluresult;

    always_ff @(posedge clk) begin
        if (!start) begin
            cflow_mode      <= CFLOW_PCPLUS4;
            branch_mode     <= BRANCH_BEQ;
            in_a            <= 32'b0;
            in_b            <= 32'b0;
            pred_taken      <= 0;
            pc_pred         <= 32'b0;
            aluresult       <= 32'b0;
        end
        else begin
            cflow_mode      <= cflow_mode_reg;
            branch_mode     <= branch_mode_reg;
            in_a            <= in_a_reg;
            in_b            <= in_b_reg;
            pred_taken      <= pred_taken_reg;
            pc_pred         <= pc_pred_reg;
            aluresult       <= aluresult_reg;
        end
    end

    assign pc_jump = aluresult & ~32'd1;

    logic lt, ltu, eq;
    always_comb begin
        lt  = $signed(in_a) < $signed(in_b);
        ltu = in_a < in_b;
        eq  = (in_a == in_b);
    end
    
    logic branch_taken;
    assign branch_taken =
        (branch_mode == BRANCH_BEQ  && eq)  ||
        (branch_mode == BRANCH_BNE  && !eq) ||
        (branch_mode == BRANCH_BLT  && lt)  ||
        (branch_mode == BRANCH_BGE  && !lt) ||
        (branch_mode == BRANCH_BLTU && ltu) ||
        (branch_mode == BRANCH_BGEU && !ltu);
        
    always_comb begin
        unique case (cflow_mode)
            CFLOW_BRANCH: begin
                cflow_valid = 1;
                cflow_taken = branch_taken;
            end
            CFLOW_JAL, CFLOW_JALR: begin
                cflow_valid = 1;
                cflow_taken = 1;
            end
            default: begin
                cflow_valid = 0;
                cflow_taken = 0;
            end
        endcase
    end

    logic miss_1, miss_2;
    always_comb begin
        miss_1          = cflow_taken != pred_taken;
        miss_2          = cflow_taken && (pc_pred != pc_jump);
        mispredict      = cflow_valid && (miss_1 || miss_2);
    end
    
endmodule