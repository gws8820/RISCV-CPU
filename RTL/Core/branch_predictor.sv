timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_predictor (
    input   logic               start,
    input   logic               clk,
    
    // Predict (IF)
    input   logic [31:0]        pc_f,
    output  logic               pred_taken,
    output  logic [31:0]        pred_target,
    
    // Update (EX)
    input   logic [31:0]        pc_e,
    input   logic               cflow_valid,
    input   logic               cflow_taken,
    input   logic [31:0]        cflow_target
);

    logic   bht_taken, btb_hit;
    assign  pred_taken  = bht_taken && btb_hit;

    logic [31:0]                pc_e_reg;
    logic                       cflow_valid_reg;
    logic                       cflow_taken_reg;
    logic [31:0]                cflow_target_reg;

    always_ff @(posedge clk) begin
        if (!start) begin
            pc_e_reg            <= 32'b0;
            cflow_valid_reg     <= 0;
            cflow_taken_reg     <= 0;
            cflow_target_reg    <= 32'b0;
        end
        else begin
            pc_e_reg            <= pc_e;
            cflow_valid_reg     <= cflow_valid;
            cflow_taken_reg     <= cflow_taken;
            cflow_target_reg    <= cflow_target;
        end
    end

    branch_history_table bht (
        .clk                    (clk),
        .pc_f                   (pc_f),
        .bht_taken              (bht_taken),
        .pc_e                   (pc_e_reg),
        .cflow_valid            (cflow_valid_reg),
        .cflow_taken            (cflow_taken_reg)
    );
    
    branch_target_buffer btb (
        .clk                    (clk),
        .pc_f                   (pc_f),
        .btb_hit                (btb_hit),
        .pred_target            (pred_target),
        .pc_e                   (pc_e_reg),
        .cflow_valid            (cflow_valid_reg),
        .cflow_taken            (cflow_taken_reg),
        .cflow_target           (cflow_target_reg)
    );

endmodule