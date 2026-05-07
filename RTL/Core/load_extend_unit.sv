timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module load_extend_unit (
    input   memaccess_t         memaccess,
    input   logic [31:0]        rdata,
    input   logic [1:0]         byte_offset,
    input   mask_mode_t         mask_mode,
    output  logic [31:0]        rdata_ext
);

    logic [31:0] rdata_shifted;
    assign rdata_shifted = rdata >> {byte_offset, 3'b000};

    always_comb begin
        rdata_ext = 32'b0;

        if (memaccess == MEM_READ) begin
            case (mask_mode)
                MASK_BYTE:      rdata_ext = {{24{rdata_shifted[7]}},    rdata_shifted[7:0]};
                MASK_BYTE_U:    rdata_ext = {24'b0,                     rdata_shifted[7:0]};
                MASK_HALF:      rdata_ext = {{16{rdata_shifted[15]}},   rdata_shifted[15:0]};
                MASK_HALF_U:    rdata_ext = {16'b0,                     rdata_shifted[15:0]};
                MASK_WORD:      rdata_ext = rdata_shifted;
                default:        rdata_ext = 32'b0;
            endcase
        end
    end

endmodule
