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

longint         total_cycles;
longint         loaduse_stall_cycles;
longint         muldiv_stall_cycles;
longint         mispredict_events;

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

    total_cycles         = 0;
    loaduse_stall_cycles = 0;
    muldiv_stall_cycles  = 0;
    mispredict_events    = 0;

    #20 start  = 1;

    #(CLK_PERIOD * 10000000);
    $display("[TIMEOUT]");
    $finish;
end

always @(posedge clk) begin
    if (start) begin
        total_cycles <= total_cycles + 1;
        if (dut.hazard_unit.stall_loaduse)    loaduse_stall_cycles <= loaduse_stall_cycles + 1;
        if (dut.hazard_unit.stall_muldiv)     muldiv_stall_cycles  <= muldiv_stall_cycles  + 1;
        if (dut.hazard_unit.flush_mispredict) mispredict_events    <= mispredict_events    + 1;
    end
end

always @(posedge clk) begin
    if (boot_en) begin
        $display("[BOOT]");
    end
    if (exit_en) begin
        $display("--- Stall Statistics ---");
        $display("Total cycles       : %0d", total_cycles);
        $display("Load-use stalls    : %0d cycles (%.1f%%)", loaduse_stall_cycles, 100.0 * loaduse_stall_cycles / total_cycles);
        $display("Mul/Div stalls     : %0d cycles (%.1f%%)", muldiv_stall_cycles,  100.0 * muldiv_stall_cycles  / total_cycles);
        $display("Branch mispredicts : %0d events (~%0d cycles, %.1f%%)", mispredict_events, mispredict_events * 3, 100.0 * mispredict_events * 3 / total_cycles);
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
