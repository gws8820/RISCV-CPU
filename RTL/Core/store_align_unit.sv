timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module store_align_unit (
    input   memaccess_t     memaccess,
    input   logic [31:0]    data,
    input   logic [1:0]     byte_offset,
    input   mask_mode_t     mask_mode,
    output  logic [3:0]     wstrb,
    output  logic [31:0]    wdata
);

    always_comb begin
        if (memaccess == MEM_WRITE) begin
            unique case(mask_mode)
                MASK_BYTE:  begin
                    wstrb = 4'b0001 << byte_offset;
                    wdata = {24'b0, data[7:0]} << (8 * byte_offset);
                end
                MASK_HALF:  begin
                    wstrb = 4'b0011 << byte_offset;
                    wdata = {16'b0, data[15:0]} << (8 * byte_offset);
                end
                MASK_WORD:  begin
                    wstrb = 4'b1111;
                    wdata = data;
                end
                default:    begin
                    wstrb = 4'b0000;
                    wdata = 32'b0;
                end
            endcase
        end
        else begin
            wstrb = 4'b0000;
            wdata = 32'b0;
        end
    end

endmodule