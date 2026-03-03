timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_wb (
    input   logic                   start, clk,

    input   control_bus_t           control_bus_m2,
    input   logic [4:0]             rd_m2,
    input   logic [31:0]            memresult_m2,
    input   logic [31:0]            result_m2,

    output  logic                   regwrite_w,
    output  logic [4:0]             rd_w,
    output  logic [31:0]            result_w,
    output  logic                   instret_w
);

    control_bus_t                   control_bus_w;

    logic [31:0]                    memresult_w;
    logic [31:0]                    result_w_prev;

    always_ff@(posedge clk) begin
        if (!start) begin
            control_bus_w           <= '0;
        end
        else begin
            control_bus_w           <= control_bus_m2;
            rd_w                    <= rd_m2;
            memresult_w             <= memresult_m2;
            result_w_prev           <= result_m2;
        end
    end

    assign instret_w  = control_bus_w.valid;
    assign regwrite_w = control_bus_w.regwrite;
    
    // Result Selector
    always_comb begin
        unique case(control_bus_w.resultsrc)
            RESULT_MEM:             result_w = memresult_w;
            default:                result_w = result_w_prev;
        endcase
    end
    
endmodule