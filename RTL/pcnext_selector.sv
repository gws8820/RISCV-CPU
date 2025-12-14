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

    (* mark_debug = "true", keep = "true" *) pcsrc_t pcsrc;

    always_comb begin
        priority if (trap_redir) begin
            pcsrc           = PC_TRAP;
        end
        else if (mispredict) begin
            if (cflow_taken) begin
                pcsrc       = PC_JUMP;
            end
            else begin
                pcsrc       = PC_RETURN;
            end
        end
        else if (pred_taken) begin
            pcsrc           = PC_PRED;
        end
        else begin
            pcsrc           = PC_PCPLUS4;
        end

        case (pcsrc)
            PC_PCPLUS4:     pc_next = pcplus4_f;
            PC_PRED:        pc_next = pc_pred;
            PC_JUMP:        pc_next = pc_jump;
            PC_RETURN:      pc_next = pc_return;
            PC_TRAP:        pc_next = trap_addr;
            default:        pc_next = 32'b0;
        endcase
    end

endmodule

