timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_load_use_resolver (
    input   memaccess_t     memaccess_e, memaccess_m1,
    input   logic           use_rs1_d, use_rs2_d,
    input   logic [4:0]     rs1_d, rs2_d,
    input   logic [4:0]     rd_e, rd_m1,
    output  logic           flag,
    output  logic           stall,
    output  logic           flush
);

    logic id_ex, id_mem1;
    always_comb begin
        id_ex   = memaccess_e  == MEM_READ && rd_e  != 0 &&
                  ((use_rs1_d && rs1_d == rd_e) || (use_rs2_d && rs2_d == rd_e));
        id_mem1 = memaccess_m1 == MEM_READ && rd_m1 != 0 &&
                  ((use_rs1_d && rs1_d == rd_m1) || (use_rs2_d && rs2_d == rd_m1));
    end

    always_comb begin
        if (id_ex || id_mem1) begin
            flag    = 1;
            stall   = 1;
            flush   = 1;
        end
        else begin
            flag    = 0;
            stall   = 0;
            flush   = 0;
        end
    end

endmodule
