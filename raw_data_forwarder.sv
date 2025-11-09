timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module raw_data_forwarder(
    input   logic       regwrite_m,
    input   logic       regwrite_w,
    input   logic [4:0] rs1_e,
    input   logic [4:0] rs2_e,
    input   logic [4:0] rd_m,
    input   logic [4:0] rd_w,
    output  logic       flag,
    output  forwarda_t  forward_a,
    output  forwardb_t  forward_b
);

    logic wb_write, mem_write;
    always_comb begin
        wb_write    = regwrite_w && rd_w != 5'b0;
        mem_write   = regwrite_m && rd_m != 5'b0;
    end
    
    always_comb begin
        priority if (mem_write && rd_m == rs1_e) begin
            flag      = 1;
            forward_a = FWDA_MEM;
        end
        else if (wb_write && rd_w == rs1_e) begin
            flag      = 1;
            forward_a = FWDA_WB;
        end
        else begin
            flag      = 0;
            forward_a = FWDA_EX;
        end
        
        priority if (mem_write && rd_m == rs2_e) begin
            flag      = 1;
            forward_b = FWDB_MEM;
        end
        else if (wb_write && rd_w == rs2_e) begin
            flag      = 1;
            forward_b = FWDB_WB;
        end
        else begin
            flag      = 0;
            forward_b = FWDB_EX;
        end
    end
endmodule