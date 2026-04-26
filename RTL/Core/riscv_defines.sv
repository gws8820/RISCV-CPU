timeunit 1ns;
timeprecision 1ps;

package riscv_defines;
    `include "riscv_parameter.svh"
    `include "riscv_instruction.svh"
    
    `include "control_signal.svh"
    `include "branch_signal.svh"
    `include "hazard_signal.svh"
    `include "csr_signal.svh"
    `include "trap_signal.svh"
endpackage