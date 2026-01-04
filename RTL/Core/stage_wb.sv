timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_wb (
    input   logic                   start, clk,

    input   control_signal_t        control_signal_m2,
    input   logic [4:0]             rd_m2,
    input   logic [31:0]            memresult_m2,
    input   logic [31:0]            result_m2,

    output  control_signal_t        control_signal_w,
    output  logic [4:0]             rd_w,
    output  logic [31:0]            result_w,

    hazard_interface.requester      hazard_bus
);

    logic                           wb_valid;
    
    logic [31:0]                    memresult_w;
    logic [31:0]                    result_w_prev;

    always_ff@(posedge clk) begin
        if (!start) begin
            wb_valid                <= 0;
            control_signal_w        <= '0;
            rd_w                    <= 5'b0;
            memresult_w             <= 32'b0;
            result_w_prev           <= 32'b0;
        end
        else begin
            wb_valid                <= 1;
            control_signal_w        <= control_signal_m2;
            rd_w                    <= rd_m2;
            memresult_w             <= memresult_m2;
            result_w_prev           <= result_m2;
        end
    end
    
    // Result Selector
    always_comb begin
        unique case(control_signal_w.resultsrc)
            RESULT_MEM:             result_w = memresult_w;
            default:                result_w = result_w_prev;
        endcase
    end
    
    // Hazard Packet
    always_comb begin
        hazard_bus.req.rd_w         = rd_w;
        hazard_bus.req.regwrite_w   = control_signal_w.regwrite;
    end

endmodule