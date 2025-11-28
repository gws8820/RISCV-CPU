timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module inst_misalign_checker(
    input   logic [31:0]    pc,
    output  logic           instmisalign
);

    always_comb begin
        if (pc[1:0] != 2'b00) begin
            instmisalign = 1;
        end
        else begin
            instmisalign = 0;
        end
    end
endmodule
