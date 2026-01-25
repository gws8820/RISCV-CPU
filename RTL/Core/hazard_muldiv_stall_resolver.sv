timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_muldiv_stall_resolver(
    input   logic   start, clk,
    input   logic   ex_fire,
    input   aluop_t aluop_e,
    input   logic   flush_e,
    output  logic   flag,
    output  logic   stall
);
    
    logic           exec_init;
    logic [5:0]     stall_rem;

    assign exec_init = ex_fire && (aluop_e == ALUOP_MUL || aluop_e == ALUOP_DIV) && (stall_rem == 6'd0);

    always_comb begin
        flag  = exec_init || (stall_rem != 6'd0);
        stall = exec_init || (stall_rem != 6'd0);
    end

    always_ff@(posedge clk) begin
        if (!start) begin
            stall_rem <= 6'd0;
        end
        else if (flush_e) begin
            stall_rem <= 6'd0;
        end
        else if (exec_init) begin
            unique case (aluop_e)
                ALUOP_MUL:  stall_rem <= (MUL_COUNT > 0) ? (MUL_COUNT - 1) : 6'd0;
                ALUOP_DIV:  stall_rem <= (DIV_COUNT > 0) ? (DIV_COUNT - 1) : 6'd0;
                default:    stall_rem <= 6'd0;
            endcase
        end
        else if (stall_rem != 6'd0) begin
            stall_rem       <= stall_rem - 1;
        end
    end

endmodule
