timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_unit (
    input   nextpc_mode_t   nextpc_mode,
    input   branch_mode_t   branch_mode,
    input   logic [31:0]    in_a, in_b,
    input   logic           redirflag,
    output  pcsrc_t         pcsrc
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
        if (redirflag) pcsrc = PC_REDIR;
        else unique case (nextpc_mode)
            NEXTPC_PLUS4:   pcsrc = PC_PLUS4;
            NEXTPC_BRANCH:  pcsrc = (branch_taken ? PC_PLUSIMM : PC_PLUS4);
            NEXTPC_JAL:     pcsrc = PC_PLUSIMM;
            NEXTPC_JALR:    pcsrc = PC_ALU;
            default: pcsrc = PC_PLUS4;
        endcase
    end
endmodule