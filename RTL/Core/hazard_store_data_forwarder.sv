timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_store_data_forwarder (
    input   memaccess_t memaccess_m1,
    input   logic       regwrite_w,
    input   logic [4:0] rd_w,
    input   logic [4:0] rs2_m1,
    output  logic       flag,
    output  logic       forward_m1
);

    always_comb begin
        if (
            memaccess_m1 == MEM_WRITE &&
            regwrite_w &&
            rd_w != 0 &&
            rd_w == rs2_m1
        ) begin
            flag        = 1;
            forward_m1  = 1;
        end
        else begin
            flag        = 0;
            forward_m1  = 0;
        end
    end

endmodule