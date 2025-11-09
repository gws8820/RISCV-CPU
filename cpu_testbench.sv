timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module cpu_testbench();

logic rstn, clk;

pipelined_rv32i_cpu dut (
    .rstn (rstn),
    .clk  (clk)
);

always #(CLK_PERIOD/2) clk = ~clk;

initial begin
    #0  clk = 0; rstn = 0;
    #20 rstn = 1;
end

endmodule
