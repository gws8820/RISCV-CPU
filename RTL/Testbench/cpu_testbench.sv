timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module cpu_testbench();

logic start;
logic clk;

logic prog_en;
logic [31:0] prog_addr;
logic [31:0] prog_data;

logic print_en;
logic [31:0] print_data;

riscv_cpu_core dut (
    .start      (start),
    .clk        (clk),
    .prog_en    (prog_en),
    .prog_addr  (prog_addr),
    .prog_data  (prog_data),
    .print_en   (print_en),
    .print_data (print_data)
);

always #(CLK_PERIOD/2) clk = ~clk;

initial begin
    start       = 0;
    clk         = 0;
    prog_en     = 0;
    prog_addr   = '0;
    prog_data   = '0;

    #20 start  = 1;
end

endmodule
