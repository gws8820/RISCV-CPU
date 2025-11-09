timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module single_cycle_trap_pkt_gen(
    input [31:0] pc,
    input [31:0] dataaddr,
    input inst_t inst,
    input memaccess_t memaccess,
    input instillegal,
    input instmisalign, datamisalign,
    input imemfault, dmemfault,
    input cflow_mode_t cflow_mode,
    output trap_pkt_t trap_pkt
);

    always_comb begin
        trap_pkt.valid          = 0;
        trap_pkt.mode           = TRAP_NONE;
        trap_pkt.cause          = CAUSE_INST_MISALIGNED; // Default
        trap_pkt.pc             = 32'b0;
        trap_pkt.tval           = 32'b0;
    
        unique if (dmemfault) begin
            trap_pkt.valid      = 1;
            trap_pkt.mode       = TRAP_ENTER;
            trap_pkt.pc         = pc;
            trap_pkt.cause      = (memaccess == MEM_WRITE) ? CAUSE_STORE_ACCESS_FAULT : CAUSE_LOAD_ACCESS_FAULT;
            trap_pkt.tval       = dataaddr;
        end
        
        else if (cflow_mode == CFLOW_MRET) begin
            trap_pkt.valid      = 1;
            trap_pkt.mode       = TRAP_RETURN;
            trap_pkt.pc         = pc;
            trap_pkt.cause      = CAUSE_INST_MISALIGNED; // Default
            trap_pkt.tval       = 32'b0;
        end
        
        else if (cflow_mode == CFLOW_ECALL) begin
            trap_pkt.valid      = 1;
            trap_pkt.mode       = TRAP_ENTER;
            trap_pkt.pc         = pc;
            trap_pkt.cause      = CAUSE_ECALL_MMODE;
            trap_pkt.tval       = 32'b0;
        end
        
        else if (cflow_mode == CFLOW_EBREAK) begin
            trap_pkt.valid      = 1;
            trap_pkt.mode       = TRAP_ENTER;
            trap_pkt.pc         = pc;
            trap_pkt.cause      = CAUSE_BREAKPOINT;
            trap_pkt.tval       = 32'b0;
        end
        
        else if (datamisalign) begin
            trap_pkt.valid      = 1;
            trap_pkt.mode       = TRAP_ENTER;
            trap_pkt.pc         = pc;
            trap_pkt.cause      = (memaccess == MEM_WRITE) ? CAUSE_STORE_ADDR_MISALIGN : CAUSE_LOAD_ADDR_MISALIGN;
            trap_pkt.tval       = dataaddr;
        end
        
        else if (instillegal) begin
            trap_pkt.valid      = 1;
            trap_pkt.mode       = TRAP_ENTER;
            trap_pkt.pc         = pc;
            trap_pkt.cause      = CAUSE_ILLEGAL_INSTRUCTION;
            trap_pkt.tval       = inst;
        end
        
        else if (instmisalign) begin
            trap_pkt.valid      = 1;
            trap_pkt.mode       = TRAP_ENTER;
            trap_pkt.pc         = pc;
            trap_pkt.cause      = CAUSE_INST_MISALIGNED;
            trap_pkt.tval       = pc;
        end
        
        else if (imemfault) begin
            trap_pkt.valid      = 1;
            trap_pkt.mode       = TRAP_ENTER;
            trap_pkt.pc         = pc;
            trap_pkt.cause      = CAUSE_INST_ACCESS_FAULT;
            trap_pkt.tval       = pc;
        end
           
        else ;
    end
endmodule
