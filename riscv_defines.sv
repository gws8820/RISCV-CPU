timeunit 1ns;
timeprecision 1ps;

package riscv_defines;
    `include "riscv_parameter.svh"
    `include "riscv_instruction.svh"
    
    `include "riscv_control_signal.svh"
    `include "riscv_hazard_signal.svh"
    `include "riscv_trap_signal.svh"
    `include "riscv_csr_signal.svh"
endpackage 