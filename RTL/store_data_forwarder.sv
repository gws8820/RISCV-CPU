timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module store_data_forwarder (
    input   memaccess_t memaccess_m,
    input   logic       regwrite_w,
    input   logic [4:0] rd_w,
    input   logic [4:0] rs2_m,
    output  logic       flag,
    output  logic       forward_mem
);

    always_comb begin
        if (
            memaccess_m == MEM_WRITE &&
            regwrite_w &&
            rd_w != 0 &&
            rd_w == rs2_m
        ) begin
            flag        = 1;
            forward_mem = 1;
        end
        else begin
            flag        = 0;
            forward_mem = 0;
        end
    end

endmodule