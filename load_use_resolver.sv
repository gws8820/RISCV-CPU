timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module load_use_resolver (
    input   memaccess_t memaccess_e,
    input   logic [4:0] rd_e,
    input   logic [4:0] rs1_d, rs2_d,
    output  logic       flag,
    output  logic       stall_f,
    output  logic       stall_d,
    output  logic       flush_e
);

    always_comb begin
        if (
            memaccess_e == MEM_READ &&
            rd_e != 0 &&
            (rd_e == rs1_d || rd_e == rs2_d)
        ) begin
            flag    = 1;
            stall_f = 1;
            stall_d = 1;
            flush_e = 1;
        end
        else begin
            flag    = 0;
            stall_f = 0;
            stall_d = 0;
            flush_e = 0;
        end
    end

endmodule