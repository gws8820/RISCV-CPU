timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_unit (
    input   logic               start, clk,
    input   logic               flush,
    input   logic               ex_fire,
    input   cflow_mode_t        cflow_mode,
    input   branch_mode_t       branch_mode,
    input   cflow_hint_t        cflow_hint,
    input   logic [31:0]        in_a, in_b,
    input   logic               pred_taken,
    input   logic [31:0]        pc_pred,
    input   logic [31:0]        aluresult,
    output  logic [31:0]        pc_jump,
    output  cflow_mode_t        cflow_mode_reg,
    output  cflow_hint_t        cflow_hint_reg,
    output  logic               cflow_taken,
    output  logic               mispredict
);

    logic                       branch_valid;

    // -----------------------------
    //       Input Registering
    // -----------------------------

    branch_mode_t               branch_mode_reg;
    logic [31:0]                in_a_reg, in_b_reg;
    logic                       pred_taken_reg;
    logic [31:0]                pc_pred_reg;
    logic [31:0]                aluresult_reg;

    always_ff @(posedge clk) begin
        if (!start) begin
            branch_valid        <= 0;
        end
        else begin
            priority if (flush) begin
                branch_valid    <= 0;
            end
            else if (ex_fire) begin
                branch_valid    <= 1;
                cflow_mode_reg  <= cflow_mode;
                branch_mode_reg <= branch_mode;
                cflow_hint_reg  <= cflow_hint;
                in_a_reg        <= in_a;
                in_b_reg        <= in_b;
                pred_taken_reg  <= pred_taken;
                pc_pred_reg     <= pc_pred;
                aluresult_reg   <= aluresult;
            end
            else begin
                branch_valid    <= 0;
            end
        end
    end

    logic lt, ltu, eq;
    always_comb begin
        lt  = $signed(in_a_reg) < $signed(in_b_reg);
        ltu = in_a_reg < in_b_reg;
        eq  = (in_a_reg == in_b_reg);
    end

    logic branch_taken;
    assign branch_taken =
        (branch_mode_reg == BRANCH_BEQ  && eq)  ||
        (branch_mode_reg == BRANCH_BNE  && !eq) ||
        (branch_mode_reg == BRANCH_BLT  && lt)  ||
        (branch_mode_reg == BRANCH_BGE  && !lt) ||
        (branch_mode_reg == BRANCH_BLTU && ltu) ||
        (branch_mode_reg == BRANCH_BGEU && !ltu);

    always_comb begin
        if (!branch_valid) begin
            cflow_taken         = 0;
        end
        else begin
            unique case (cflow_mode_reg)
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

    logic cflow_valid, pred_hit;
    logic miss_1, miss_2;

    assign pc_jump      = branch_valid ? (aluresult_reg & ~32'd1) : 32'b0;

    always_comb begin
        cflow_valid     = cflow_mode_reg inside {CFLOW_BRANCH, CFLOW_JAL, CFLOW_JALR};
        miss_1          = cflow_taken   != pred_taken_reg;
        miss_2          = cflow_taken   && (pc_pred_reg != pc_jump);
        mispredict      = branch_valid  && cflow_valid && (miss_1 || miss_2);
        pred_hit        = cflow_valid   && !mispredict;
    end

endmodule
