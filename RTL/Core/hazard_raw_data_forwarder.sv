timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_raw_data_forwarder(
    input   logic       regwrite_m1, regwrite_m2, regwrite_w,
    input   memaccess_t memaccess_m1, memaccess_m2,
    input   logic [4:0] rs1_e, rs2_e,
    input   logic [4:0] rd_m1, rd_m2, rd_w,
    output  logic       flag,
    output  forward_e_t forwarda_e,
    output  forward_e_t forwardb_e
);

    logic   mem1_write, mem2_write, wb_write;
    logic   flag_1, flag_2;
    
    always_comb begin
        mem1_write  = regwrite_m1 && rd_m1 != 5'b0 && memaccess_m1 != MEM_READ;
        mem2_write  = regwrite_m2 && rd_m2 != 5'b0 && memaccess_m2 != MEM_READ;
        wb_write    = regwrite_w  && rd_w != 5'b0;

        flag        = flag_1 || flag_2;
    end

    always_comb begin
        priority if (mem1_write && rd_m1 == rs1_e) begin
            flag_1      = 1;
            forwarda_e  = FWD_MEM1;
        end
        else if (mem2_write && rd_m2 == rs1_e) begin
            flag_1      = 1;
            forwarda_e  = FWD_MEM2;
        end
        else if (wb_write && rd_w == rs1_e) begin
            flag_1      = 1;
            forwarda_e  = FWD_WB;
        end
        else begin
            flag_1      = 0;
            forwarda_e  = FWD_EX;
        end
        
        priority if (mem1_write && rd_m1 == rs2_e) begin
            flag_2      = 1;
            forwardb_e  = FWD_MEM1;
        end
        else if (mem2_write && rd_m2 == rs2_e) begin
            flag_2      = 1;
            forwardb_e  = FWD_MEM2;
        end
        else if (wb_write && rd_w == rs2_e) begin
            flag_2      = 1;
            forwardb_e  = FWD_WB;
        end
        else begin
            flag_2      = 0;
            forwardb_e  = FWD_EX;
        end
    end

endmodule