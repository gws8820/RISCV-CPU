timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_branch_mispredict_resolver (
    input   logic   mispredict,
    output  logic   flag,
    output  logic   flush_d,
    output  logic   flush_e
);

    always_comb begin
        if (mispredict) begin
            flag    = 1;
            flush_d = 1;
            flush_e = 1;
        end
        else begin
            flag    = 0;
            flush_d = 0;
            flush_e = 0;
        end
    end

endmodule