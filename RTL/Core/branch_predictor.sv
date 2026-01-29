timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_predictor (
    input   logic               start, clk,
    
    // Predict
    input   logic [31:0]        pc_f,
    output  logic               pred_taken,
    output  logic [31:0]        pred_target,
    
    // Update
    input   logic [31:0]        pc_e,
    input   cflow_mode_t        cflow_mode,
    input   cflow_hint_t        cflow_hint,
    input   logic               cflow_taken,
    input   logic [31:0]        cflow_target
);

    logic   is_branch;
    assign  is_branch           = (cflow_mode == CFLOW_BRANCH);


    logic                       ras_push, ras_pop;
    logic [31:0]                ras_push_addr, ras_pop_addr;
    logic                       ras_empty, ras_full;

    assign ras_push             = (cflow_hint == CFHINT_CALL) && (cflow_mode inside {CFLOW_JAL, CFLOW_JALR});
    assign ras_pop              = (cflow_hint == CFHINT_RET)  && (cflow_mode == CFLOW_JALR);
    assign ras_push_addr        = pc_e + 4;

    return_address_stack ras (
        .start                  (start),
        .clk                    (clk),
        .empty                  (ras_empty),
        .full                   (ras_full),
        .push                   (ras_push),
        .push_addr              (ras_push_addr),
        .pop                    (ras_pop),
        .pop_addr               (ras_pop_addr)
    );

    entry_type_t                entry_type;
    logic                       bht_taken, btb_hit;
    assign                      pred_taken = (entry_type == ENRTY_BRANCH) ? (bht_taken && btb_hit) : btb_hit;

    branch_history_table bht (
        .clk                    (clk),
        .pc_f                   (pc_f),
        .bht_taken              (bht_taken),
        .pc_e                   (pc_e),
        .is_branch              (is_branch),
        .cflow_taken            (cflow_taken)
    );
    
    branch_target_buffer btb (
        .clk                    (clk),
        .pc_f                   (pc_f),
        .ras_empty              (ras_empty),
        .ras_pop_addr           (ras_pop_addr),
        .pred_type              (entry_type),
        .btb_hit                (btb_hit),
        .pred_target            (pred_target),
        .pc_e                   (pc_e),
        .cflow_mode             (cflow_mode),
        .cflow_hint             (cflow_hint),
        .cflow_taken            (cflow_taken),
        .cflow_target           (cflow_target)
    );

endmodule