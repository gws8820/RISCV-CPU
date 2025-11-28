timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_mispredict_resolver (
    input   pcsrc_t pcsrc,
    input   logic   stall_d,
    output  logic   flag,
    output  logic   flush_d
);

    always_comb begin
        if (pcsrc == PC_JUMP && !stall_d) begin
            flag    = 1;
            flush_d = 1;
        end
        else begin
            flag    = 0;
            flush_d = 0;
        end
    end

endmodule