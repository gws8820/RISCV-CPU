timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_predictor (
    input   logic               start,
    input   logic               clk,
    
    // Predict
    input   logic [31:0]        pc_f,
    output  logic               pred_taken,
    output  logic [31:0]        pred_target,
    
    // Update
    input   logic [31:0]        pc_m,
    input   logic               cflow_valid,
    input   logic               cflow_taken,
    input   logic [31:0]        cflow_target
);

    logic   bht_taken, btb_hit;
    assign  pred_taken  = bht_taken && btb_hit;

    branch_history_table bht (
        .clk                    (clk),
        .pc_f                   (pc_f),
        .bht_taken              (bht_taken),
        .pc_m                   (pc_m),
        .cflow_valid            (cflow_valid),
        .cflow_taken            (cflow_taken)
    );
    
    branch_target_buffer btb (
        .clk                    (clk),
        .pc_f                   (pc_f),
        .btb_hit                (btb_hit),
        .pred_target            (pred_target),
        .pc_m                   (pc_m),
        .cflow_valid            (cflow_valid),
        .cflow_taken            (cflow_taken),
        .cflow_target           (cflow_target)
    );

endmodule