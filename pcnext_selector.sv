timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module pcnext_selector (
    input   logic [31:0]    pcplus4_f,
    input   logic [31:0]    pc_jump,
    input   logic [31:0]    pc_return,
    input   logic [31:0]    pc_pred,
    input   logic           trap_redir,
    input   logic [31:0]    trap_addr,
    input   logic           mispredict,
    input   logic           cflow_taken,
    input   logic           pred_taken,
    output  logic [31:0]    pc_next
);

    always_comb begin
        priority if (trap_redir) begin
            pc_next         = trap_addr;
        end
        else if (mispredict) begin
            if (cflow_taken) begin
                pc_next     = pc_jump;
            end
            else begin
                pc_next     = pc_return;
            end
        end
        else if (pred_taken) begin
            pc_next         = pc_pred;
        end
        else begin
            pc_next         = pcplus4_f;
        end
    end

endmodule

