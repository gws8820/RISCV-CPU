timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_unit (
    input   cflow_mode_t    cflow_mode,
    input   branch_mode_t   branch_mode,
    input   logic [31:0]    in_a, in_b,
    input   logic           stall_d,
    input   logic           pred_taken_d,
    input   logic [31:0]    pc_pred_d,
    input   logic [31:0]    pc_jump,
    output  logic           cflow_valid,
    output  logic           cflow_taken,
    output  logic           mispredict
);

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
        if (stall_d) begin
            cflow_valid         = 0;
            cflow_taken         = 0;
        end
        else begin
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
    end

    logic miss_1, miss_2;
    always_comb begin
        miss_1      = cflow_taken != pred_taken_d;
        miss_2      = cflow_taken && (pc_pred_d != pc_jump);
        mispredict  = cflow_valid && (miss_1 || miss_2);
    end
    
endmodule