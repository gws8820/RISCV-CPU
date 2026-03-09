timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module cpu_testbench();

logic           start;
logic           clk;

logic           prog_en;
logic [31:0]    prog_addr;
logic [31:0]    prog_data;

logic           boot_en;
logic           exit_en;
logic [7:0]     exit_code;
logic           print_en;
logic [31:0]    print_data;

riscv_cpu_core dut (
    .start          (start),
    .clk            (clk),
    .prog_en        (prog_en),
    .prog_addr      (prog_addr),
    .prog_data      (prog_data),
    .boot_en        (boot_en),
    .exit_en        (exit_en),
    .exit_code      (exit_code),
    .print_en       (print_en),
    .print_data     (print_data),
    .input_valid    (1'b0),
    .input_data     (8'h0),
    .input_done     ()
);

always #(CLK_PERIOD/2) clk = ~clk;

initial begin
    start       = 0;
    clk         = 0;
    prog_en     = 0;
    prog_addr   = '0;
    prog_data   = '0;

    #20 start  = 1;

    #(CLK_PERIOD * 10000000);
    $display("[TIMEOUT]");
    $finish;
end

always @(posedge clk) begin
    if (boot_en) begin
        $display("[BOOT]");
    end
    if (exit_en) begin
        if (exit_code == 0)
            $display("[PASS]");
        else
            $display("[FAIL: exit=%0d]", exit_code);
        $finish;
    end
    if (print_en) begin
        $write("%c", print_data[7:0]);
    end
end

endmodule
