timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_branch_mispredict_resolver (
    input   logic   mispredict,
    output  logic   flag,
    output  logic   flush
);

    always_comb begin
        if (mispredict) begin
            flag    = 1;
            flush   = 1;
        end
        else begin
            flag    = 0;
            flush   = 0;
        end
    end

endmodule