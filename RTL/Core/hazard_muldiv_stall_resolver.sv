timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_muldiv_stall_resolver (
    input   logic                           start, clk,
    input   logic                           ex_fire,
    input   aluop_t                         aluop_e,
    input   logic                           muldiv_valid,
    input   logic                           flush_e,
    output  logic                           flag,
    output  logic                           stall,
    output  logic                           flush
);

    logic                                   exec_init;
    logic                                   muldiv_busy;

    assign exec_init                        = ex_fire && (aluop_e == ALUOP_MUL || aluop_e == ALUOP_DIV) && !muldiv_busy;

    always_comb begin
        flag                                = exec_init || (muldiv_busy && !muldiv_valid);
        stall                               = exec_init || (muldiv_busy && !muldiv_valid);
        flush                               = exec_init || (muldiv_busy && !muldiv_valid);
    end

    always_ff @(posedge clk) begin
        if (!start) begin
            muldiv_busy                     <= 0;
        end
        else if (flush_e) begin
            muldiv_busy                     <= 0;
        end
        else if (exec_init) begin
            muldiv_busy                     <= 1;
        end
        else if (muldiv_valid) begin
            muldiv_busy                     <= 0;
        end
    end

endmodule
