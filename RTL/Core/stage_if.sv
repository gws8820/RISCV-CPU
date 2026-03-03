timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_if (
    input   logic                   start, clk,

    input   logic [31:0]            pc_pred,
    input   logic [31:0]            pc_jump,
    input   logic [31:0]            pc_return,
    input   logic                   mispredict,
    input   logic                   cflow_taken,
    input   logic                   pred_taken,

    output  logic [31:0]            pc_f,
    output  logic [31:0]            pcplus4_f,
    output  inst_t                  inst_f,
    
    input   trap_res_t              trap_res,
    output  trap_req_t              trap_req_f,
    output  logic                   instmisalign,
    output  logic                   imemfault,
    input   hazard_res_t            hazard_res,
    
    input   logic                   prog_en,
    input   logic [31:0]            prog_addr,
    input   logic [31:0]            prog_data
);

    // PCNext Selector
    logic [31:0] pc_next;
    assign pcplus4_f = pc_f + 4;
    
    pcnext_selector pcnext_selector (
        .pcplus4_f                  (pcplus4_f),
        .pc_jump                    (pc_jump),
        .pc_return                  (pc_return),
        .pc_pred                    (pc_pred),
        .trap_redir                 (trap_res.redirflag),
        .trap_addr                  (trap_res.rediraddr),
        .mispredict                 (mispredict),
        .cflow_taken                (cflow_taken),
        .pred_taken                 (pred_taken),
        .pc_next                    (pc_next)
    );

    // Program Counter
    program_counter program_counter (
        .start                      (start), // Starts PC from Zero
        .clk                        (clk),
        .stall                      (hazard_res.stall_f),
        .pc_next                    (pc_next),
        .pc                         (pc_f)
    );

    // Inst Misalign Checker
    inst_misalign_checker inst_misalign_checker (
        .pc                         (pc_f),
        .instmisalign               (instmisalign)
    );

    // Instruction Memory
    instruction_memory instruction_memory (
        .start                      (start),
        .clk                        (clk),
        .stall                      (hazard_res.stall_f), // Although stall_d is the precise signal, stall_f is used here because both stages stall in tandem.
        .pc                         (pc_f),
        .instmisalign               (instmisalign),
        .imemfault                  (imemfault),
        .inst                       (inst_f),
        
        .prog_en                    (prog_en),
        .prog_addr                  (prog_addr),
        .prog_data                  (prog_data)
    );
    
    // Trap Packet
    always_comb begin
        if (!start) begin
            trap_req_f              = '0;
        end
        else begin
            if (instmisalign) begin
                trap_req_f.valid    = 1;
                trap_req_f.mode     = TRAP_ENTER;
                trap_req_f.cause    = CAUSE_INST_MISALIGNED;
                trap_req_f.pc       = pc_f;
                trap_req_f.tval     = pc_f;
            end
            else if (imemfault) begin
                trap_req_f.valid    = 1;
                trap_req_f.mode     = TRAP_ENTER;
                trap_req_f.cause    = CAUSE_INST_ACCESS_FAULT;
                trap_req_f.pc       = pc_f;
                trap_req_f.tval     = pc_f;
            end
            else trap_req_f         = '0;
        end
    end


endmodule