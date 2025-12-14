timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_wb (
    input   logic                   start, clk,

    input   control_signal_t        control_signal_m,
    input   logic [4:0]             rd_m,
    input   logic [31:0]            memresult_m,
    input   logic [31:0]            result_m,


    output  control_signal_t        control_signal_w,
    output  logic                   kill_w,
    output  logic [4:0]             rd_w,
    output  logic [31:0]            result_w,

    input   trap_req_t              trap_req_m,
    hazard_interface.requester      hazard_bus
);

    logic [31:0]                    result_w_prev;
    logic [31:0]                    memresult_w;

    trap_req_t                      trap_req_w;

    always_ff@(posedge clk) begin
        if (!start) begin
            control_signal_w        <= '0;
            rd_w                    <= 5'b0;
            result_w_prev           <= 32'b0;

            trap_req_w              <= '0;
        end
        else begin
            control_signal_w        <= control_signal_m;
            rd_w                    <= rd_m;
            result_w_prev           <= result_m;
            
            trap_req_w              <= trap_req_m;
        end
    end
    
    always_comb begin
        memresult_w                 = memresult_m;
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
    
    // Trap Packet
    always_comb begin
        kill_w                      = trap_req_w.valid;
    end

endmodule