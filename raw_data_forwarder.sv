timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module raw_data_forwarder(
    input   logic       regwrite_e,
    input   logic       regwrite_m,
    input   logic       regwrite_w,
    input   logic [4:0] rs1_d,
    input   logic [4:0] rs2_d,
    input   logic [4:0] rs1_e,
    input   logic [4:0] rs2_e,
    input   logic [4:0] rd_e,
    input   logic [4:0] rd_m,
    input   logic [4:0] rd_w,
    output  logic       flag_d,
    output  logic       flag_e,
    output  forward_t   forwarda_d,
    output  forward_t   forwardb_d,
    output  forward_t   forwarda_e,
    output  forward_t   forwardb_e
);

    logic   ex_write, mem_write, wb_write;
    logic   flag_d1, flag_d2, flag_e1, flag_e2;
    
    always_comb begin
        ex_write    = regwrite_e && rd_e != 5'b0;
        mem_write   = regwrite_m && rd_m != 5'b0;
        wb_write    = regwrite_w && rd_w != 5'b0;

        flag_d      = flag_d1 || flag_d2;
        flag_e      = flag_e1 || flag_e2;
    end

    always_comb begin
        priority if (ex_write && rd_e == rs1_d) begin
            flag_d1     = 1;
            forwarda_d  = FWD_EX;
        end
        else if (mem_write && rd_m == rs1_d) begin
            flag_d1     = 1;
            forwarda_d  = FWD_MEM;
        end
        else if (wb_write && rd_w == rs1_d) begin
            flag_d1     = 1;
            forwarda_d  = FWD_WB;
        end
        else begin
            flag_d1     = 0;
            forwarda_d  = FWD_ID;
        end
        
        priority if (ex_write && rd_e == rs2_d) begin
            flag_d2     = 1;
            forwardb_d  = FWD_EX;
        end
        else if (mem_write && rd_m == rs2_d) begin
            flag_d2     = 1;
            forwardb_d  = FWD_MEM;
        end
        else if (wb_write && rd_w == rs2_d) begin
            flag_d2     = 1;
            forwardb_d  = FWD_WB;
        end
        else begin
            flag_d2     = 0;
            forwardb_d  = FWD_ID;
        end
    end
        
    always_comb begin
        priority if (mem_write && rd_m == rs1_e) begin
            flag_e1     = 1;
            forwarda_e  = FWD_MEM;
        end
        else if (wb_write && rd_w == rs1_e) begin
            flag_e1     = 1;
            forwarda_e  = FWD_WB;
        end
        else begin
            flag_e1     = 0;
            forwarda_e  = FWD_EX;
        end
        
        priority if (mem_write && rd_m == rs2_e) begin
            flag_e2     = 1;
            forwardb_e  = FWD_MEM;
        end
        else if (wb_write && rd_w == rs2_e) begin
            flag_e2     = 1;
            forwardb_e  = FWD_WB;
        end
        else begin
            flag_e2     = 0;
            forwardb_e  = FWD_EX;
        end
    end
endmodule