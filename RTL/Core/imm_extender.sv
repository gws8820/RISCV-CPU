timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module imm_extender(
    input   inst_t              inst,
    input   immsrc_t            immsrc,
    output  logic [31:0]        immext
);

    always_comb begin
        immext = 32'b0;

        case (immsrc)
            IMM_I:              immext  = {{20{inst.i.imm[11]}}, inst.i.imm};
            IMM_S:              immext  = {{20{inst.s.imm11_5[6]}}, inst.s.imm11_5, inst.s.imm4_0};
            IMM_B:              immext  = {{19{inst.b.imm12}}, inst.b.imm12, inst.b.imm11, inst.b.imm10_5, inst.b.imm4_1, 1'b0};
            IMM_U:              immext  = {inst.u.imm31_12, 12'b0};
            IMM_J:              immext  = {{11{inst.j.imm20}}, inst.j.imm20, inst.j.imm19_12, inst.j.imm11, inst.j.imm10_1, 1'b0};
            IMM_Z:              immext  = {27'b0, inst.i.rs1};
            default:            immext  = 32'b0;
        endcase
    end

endmodule
