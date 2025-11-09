timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module trap_unit (
    input   trap_pkt_t      trap_pkt,
    output  trap_res_t      trap_res,
    
    input [31:0] mtvec_i, mepc_i
);

    always_comb begin
        trap_res.flushflag           = 0;
        trap_res.redirflag           = 0;
        trap_res.rediraddr           = 32'b0;
        
        unique case (trap_pkt.mode)
            TRAP_ENTER: begin
                trap_res.flushflag   = 1;
                trap_res.redirflag   = 1;
                trap_res.rediraddr   = {mtvec_i[31:2], 2'b00};
            end
            TRAP_RETURN: begin
                trap_res.flushflag   = 1;
                trap_res.redirflag   = 1;
                trap_res.rediraddr   = mepc_i;
            end
            default: begin
                trap_res.flushflag   = 0;
                trap_res.redirflag   = 0;
                trap_res.rediraddr   = 32'b0;
            end
        endcase
    end
endmodule