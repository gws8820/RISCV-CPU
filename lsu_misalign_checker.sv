timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module lsu_misalign_checker (
    input   logic [31:0]    aluresult,
    input   memaccess_t     memaccess,
    input   mask_mode_t     mask_mode,
    output  logic           datamisalign
);

    logic is_misaligned;
    assign is_misaligned = (mask_mode == MASK_HALF && aluresult[0] ||
                mask_mode == MASK_HALF_U && aluresult[0] ||
                mask_mode == MASK_WORD && |aluresult[1:0]);
    
    always_comb begin
        if (memaccess != MEM_DISABLED && is_misaligned) begin
            datamisalign = 1;
        end
        else begin
            datamisalign = 0;
        end
    end
endmodule