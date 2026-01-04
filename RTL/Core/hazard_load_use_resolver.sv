timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_load_use_resolver (
    input   memaccess_t     memaccess_e, memaccess_m1,
    input   logic [4:0]     rd_e, rd_m1,
    input   logic [4:0]     rs1_d, rs2_d,
    output  logic           flag,
    output  logic           stall_f,
    output  logic           stall_d,
    output  logic           flush_e
);

    logic id_ex, id_mem1;
    always_comb begin
        id_ex   = memaccess_e  == MEM_READ && rd_e != 0  && (rd_e == rs1_d || rd_e == rs2_d);
        id_mem1 = memaccess_m1 == MEM_READ && rd_m1 != 0 && (rd_m1 == rs1_d || rd_m1 == rs2_d);
    end

    always_comb begin
        if (id_ex || id_mem1) begin
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