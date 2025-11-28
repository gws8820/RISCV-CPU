timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module load_use_resolver (
    input   memaccess_t     memaccess_e, memaccess_m,
    input   nextpc_mode_t   nextpc_mode,
    input   logic [4:0]     rd_e, rd_m,
    input   logic [4:0]     rs1_d, rs2_d,
    output  logic           flag,
    output  logic           stall_f,
    output  logic           stall_d,
    output  logic           flush_e
);

    logic basic_stall, branch_stall;
    
    always_comb begin
        if (basic_stall || branch_stall) begin
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
    
    always_comb begin
        if (
            memaccess_e == MEM_READ &&
            rd_e != 0 &&
            (rd_e == rs1_d || rd_e == rs2_d)
        ) begin
            basic_stall     = 1;
        end
        else begin
            basic_stall     = 0;
        end
        
        if (
            memaccess_m == MEM_READ &&
            (nextpc_mode == NEXTPC_BRANCH || nextpc_mode == NEXTPC_JALR) &&
            rd_m != 0 &&
            (rd_m == rs1_d || rd_m == rs2_d)
        ) begin
            branch_stall    = 1;
        end
        else begin
            branch_stall    = 0;
        end
    end

endmodule