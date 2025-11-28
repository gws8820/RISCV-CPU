timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_if (
    input   logic                   start, clk,

    input   pcsrc_t                 pcsrc,
    input   logic [31:0]            pc_jump,

    output  logic [31:0]            pc_f,
    output  logic [31:0]            pcplus4_f,
    output  inst_t                  inst_f,
    
    input   trap_res_t              trap_res,
    output  trap_req_t              trap_req_f,
    hazard_interface.requester      hazard_bus
);

    trap_flag_t                     trap_flag;

    // Program Counter
    logic [31:0] pc_next;
    assign pcplus4_f = pc_f + 4;

    always_comb begin
        unique case(pcsrc)
            PC_REDIR:               pc_next = trap_res.rediraddr;
            PC_PLUS4:               pc_next = pcplus4_f;
            PC_JUMP:                pc_next = pc_jump;
            default:                pc_next = pcplus4_f;
        endcase
    end

    (* DONT_TOUCH = "true" *)
    program_counter program_counter (
        .start                      (start), // Starts PC from Zero
        .clk                        (clk),
        .stall_f                    (hazard_bus.res.stall_f),
        .pc_next                    (pc_next),
        .pc                         (pc_f)
    );
    
    // Inst Misalign Checker
    (* DONT_TOUCH = "true" *)
    inst_misalign_checker inst_misalign_checker (
        .pc                         (pc_f),
        .instmisalign               (trap_flag.instmisalign)
    );

    // Instruction Memory
    (* DONT_TOUCH = "true" *)
    instruction_memory instruction_memory (
        .start                      (start),
        .clk                        (clk),
        .pc                         (pc_f),
        .instmisalign               (trap_flag.instmisalign),
        .flush_d                    (hazard_bus.res.flush_d),
        .stall_d                    (hazard_bus.res.stall_d),
        .imemfault                  (trap_flag.imemfault),
        .inst                       (inst_f)
    );
    
    // Hazard Packet
    always_comb begin
        hazard_bus.req.pcsrc = pcsrc;
    end
    
    // Trap Packet
    always_comb begin
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