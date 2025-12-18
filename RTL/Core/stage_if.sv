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
    hazard_interface.requester      hazard_bus,
    
    input   logic                   prog_en,
    input   logic [31:0]            prog_addr,
    input   logic [31:0]            prog_data
);

    trap_flag_t                     trap_flag;

    // Program Counter
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

    program_counter program_counter (
        .start                      (start), // Starts PC from Zero
        .clk                        (clk),
        .stall_f                    (hazard_bus.res.stall_f),
        .pc_next                    (pc_next),
        .pc                         (pc_f)
    );
    
    // Inst Misalign Checker
    inst_misalign_checker inst_misalign_checker (
        .pc                         (pc_f),
        .instmisalign               (trap_flag.instmisalign)
    );

    // Instruction Memory
    instruction_memory instruction_memory (
        .start                      (start),
        .clk                        (clk),
        .pc                         (pc_f),
        .instmisalign               (trap_flag.instmisalign),
        .imemfault                  (trap_flag.imemfault),
        .inst                       (inst_f),
        
        .prog_en                    (prog_en),
        .prog_addr                  (prog_addr),
        .prog_data                  (prog_data)
    );
    
    // Trap Packet
    always_comb begin
        trap_flag.instillegal       = 0;
        trap_flag.datamisalign      = 0;
        trap_flag.dmemfault         = 0;

        if (!start) begin
            trap_req_f              = '0;
        end
        else begin
            if (trap_flag.instmisalign) begin
                trap_req_f.valid    = 1;
                trap_req_f.mode     = TRAP_ENTER;
                trap_req_f.cause    = CAUSE_INST_MISALIGNED;
                trap_req_f.pc       = pc_f;
                trap_req_f.tval     = pc_f;
            end
            else if (trap_flag.imemfault) begin
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