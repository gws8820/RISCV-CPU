timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module hazard_raw_data_forwarder(
    input   logic       regwrite_m,
    input   logic       regwrite_w,
    input   logic [4:0] rs1_e,
    input   logic [4:0] rs2_e,
    input   logic [4:0] rd_m,
    input   logic [4:0] rd_w,
    output  logic       flag,
    output  forward_e_t forwarda_e,
    output  forward_e_t forwardb_e
);

    logic   ex_write, mem_write, wb_write;
    logic   flag_1, flag_2;
    
    always_comb begin
        mem_write   = regwrite_m && rd_m != 5'b0;
        wb_write    = regwrite_w && rd_w != 5'b0;

        flag        = flag_1 || flag_2;
    end

    always_comb begin
        priority if (mem_write && rd_m == rs1_e) begin
            flag_1      = 1;
            forwarda_e  = FWD_MEM;
        end
        else if (wb_write && rd_w == rs1_e) begin
            flag_1      = 1;
            forwarda_e  = FWD_WB;
        end
        else begin
            flag_1      = 0;
            forwarda_e  = FWD_EX;
        end
        
        priority if (mem_write && rd_m == rs2_e) begin
            flag_2      = 1;
            forwardb_e  = FWD_MEM;
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