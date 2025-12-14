timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module trap_unit (
    input   [31:0]                      mtvec_i, mepc_i,
    trap_interface.completer            trap_bus
);

    always_comb begin
        trap_bus.res.flushflag          = 0;
        trap_bus.res.redirflag          = 0;
        trap_bus.res.rediraddr          = 32'b0;
        
        unique case (trap_bus.req.mode)
            TRAP_ENTER: begin
                trap_bus.res.flushflag  = 1;
                trap_bus.res.redirflag  = 1;
                trap_bus.res.rediraddr  = {mtvec_i[31:2], 2'b00};
            end
            TRAP_RETURN: begin
                trap_bus.res.flushflag  = 1;
                trap_bus.res.redirflag  = 1;
                trap_bus.res.rediraddr  = mepc_i;
            end
            default: begin
                trap_bus.res.flushflag  = 0;
                trap_bus.res.redirflag  = 0;
                trap_bus.res.rediraddr  = 32'b0;
            end
        endcase
    end
endmodule