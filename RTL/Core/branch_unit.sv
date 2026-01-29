timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_unit (
    input   logic               start, clk,
    input   logic               flush,
    input   logic               ex_fire,
    input   cflow_mode_t        cflow_mode_reg,
    input   branch_mode_t       branch_mode_reg,
    input   cflow_hint_t        cflow_hint_reg,
    input   logic [31:0]        in_a_reg, in_b_reg,
    input   logic               pred_taken_reg,
    input   logic [31:0]        pc_pred_reg,
    input   logic [31:0]        aluresult_reg,
    output  logic [31:0]        pc_jump,
    output  cflow_mode_t        cflow_mode,
    output  cflow_hint_t        cflow_hint,
    output  logic               cflow_taken,
    output  logic               mispredict
);

    logic                       branch_valid;

    // -----------------------------
    //       Input Registering
    // -----------------------------

    branch_mode_t               branch_mode;
    logic [31:0]                in_a, in_b;
    logic                       pred_taken;
    logic [31:0]                pc_pred;
    logic [31:0]                aluresult;

    always_ff @(posedge clk) begin
        if (!start) begin
            branch_valid        <= 0;
            cflow_mode          <= CFLOW_PCPLUS4;
            cflow_hint          <= CFHINT_NONE;
        end
        else begin
            priority if (flush) begin
                branch_valid    <= 0;
                cflow_mode      <= CFLOW_PCPLUS4;
                cflow_hint      <= CFHINT_NONE;
            end
            else if (ex_fire) begin
                branch_valid    <= 1;
                cflow_mode      <= cflow_mode_reg;
                branch_mode     <= branch_mode_reg;
                cflow_hint      <= cflow_hint_reg;
                in_a            <= in_a_reg;
                in_b            <= in_b_reg;
                pred_taken      <= pred_taken_reg;
                pc_pred         <= pc_pred_reg;
                aluresult       <= aluresult_reg;
            end
            else begin
                branch_valid    <= 0;
                cflow_mode      <= CFLOW_PCPLUS4;
                cflow_hint      <= CFHINT_NONE;
            end
        end
    end

    assign pc_jump = branch_valid ? (aluresult & ~32'd1) : 32'b0;

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
        if (!branch_valid) begin
            cflow_taken         = 0;
        end
        else begin
            unique case (cflow_mode)
                CFLOW_BRANCH: begin
                    cflow_taken = branch_taken;
                end
                CFLOW_JAL, CFLOW_JALR: begin
                    cflow_taken = 1;
                end
                default: begin
                    cflow_taken = 0;
                end
            endcase
        end
    end

    logic cflow_valid;
    logic miss_1, miss_2;
    
    always_comb begin
        cflow_valid     = cflow_mode inside {CFLOW_BRANCH, CFLOW_JAL, CFLOW_JALR};
        miss_1          = cflow_taken != pred_taken;
        miss_2          = cflow_taken && (pc_pred != pc_jump);
        mispredict      = branch_valid && cflow_valid && (miss_1 || miss_2);
    end
    
endmodule