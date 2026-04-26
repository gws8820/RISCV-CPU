timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module cpu_testbench();

logic           start;
logic           clk;

memory_init_interface    rom_init();
mmio_out_interface       mmio_out();
mmio_in_interface        mmio_in();

longint         total_cycles;
longint         loaduse_stall_cycles;
longint         muldiv_stall_cycles;
longint         mispredict_events;

riscv_cpu_core dut (
    .start          (start),
    .clk            (clk),
    .rom_init       (rom_init),
    .mmio_out       (mmio_out),
    .mmio_in        (mmio_in)
);

always #(CLK_PERIOD/2) clk = ~clk;

initial begin
    start       = 0;
    clk         = 0;
    rom_init.write_enable = 0;
    rom_init.write_addr   = '0;
    rom_init.write_data   = '0;
    mmio_in.valid         = 0;
    mmio_in.data          = '0;

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
    if (mmio_out.boot_valid) begin
        $display("[BOOT]");
    end
    if (mmio_out.exit_valid) begin
        $display("--- Stall Statistics ---");
        $display("Total cycles       : %0d", total_cycles);
        $display("Load-use stalls    : %0d cycles (%.1f%%)", loaduse_stall_cycles, 100.0 * loaduse_stall_cycles / total_cycles);
        $display("Mul/Div stalls     : %0d cycles (%.1f%%)", muldiv_stall_cycles,  100.0 * muldiv_stall_cycles  / total_cycles);
        $display("Branch mispredicts : %0d events (~%0d cycles, %.1f%%)", mispredict_events, mispredict_events * 3, 100.0 * mispredict_events * 3 / total_cycles);
        if (mmio_out.exit_code == 0)
            $display("[PASS]");
        else
            $display("[FAIL: exit=%0d]", mmio_out.exit_code);
        $finish;
    end
    if (mmio_out.print_valid) begin
        $write("%c", mmio_out.print_data[7:0]);
    end
end

endmodule
