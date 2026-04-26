timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module inst_alignment_checker (
    input   logic [31:0]    pc,
    output  logic           inst_addr_misaligned
);

    always_comb begin
        if (pc[1:0] != 2'b00) begin
            inst_addr_misaligned = 1;
        end
        else begin
            inst_addr_misaligned = 0;
        end
    end
endmodule
