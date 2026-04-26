timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module data_alignment_checker (
    input   logic [31:0]    addr,
    input   memaccess_t     memaccess,
    input   mask_mode_t     mask_mode,
    output  logic           data_addr_misaligned
);

    logic   is_misaligned;
    assign  is_misaligned = ((mask_mode == MASK_HALF) && addr[0])
                         || ((mask_mode == MASK_HALF_U) && addr[0])
                         || ((mask_mode == MASK_WORD) && |addr[1:0]);
    
    always_comb begin
        if (memaccess != MEM_DISABLED && is_misaligned) begin
            data_addr_misaligned = 1;
        end
        else begin
            data_addr_misaligned = 0;
        end
    end
endmodule
