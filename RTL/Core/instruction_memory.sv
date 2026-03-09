timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module instruction_memory(
    input   logic           start, clk,
    input   logic           stall,
    input   logic [31:0]    pc,
    input   logic           instmisalign,
    output  logic           imemfault,
    output  inst_t          inst,

    input   logic           prog_en,
    input   logic [31:0]    prog_addr,
    input   logic [31:0]    prog_data
);

    logic [29:0]            pc_idx;
    assign                  pc_idx = pc[31:2];

    logic [29:0]            prog_idx;
    assign                  prog_idx = prog_addr[31:2];

    (* ram_style="block", cascade_height=1 *) logic [31:0] inst_mem [0:IMEM_WORD-1];

    `ifndef SYNTHESIS
        initial $readmemh("firmware.hex", inst_mem);
    `endif

    always_ff@(posedge clk) begin
        if (prog_en && (prog_idx < IMEM_WORD)) begin
            inst_mem[prog_idx]  <= prog_data;
        end
    end

    // IMEM Access
    always_ff@(posedge clk) begin
        if (!stall)             inst <= inst_mem[pc_idx]; // Freezes the current instruction in ID
    end

    // Fault Detection
    always_ff@(posedge clk) begin
        if (!start)             imemfault <= 0;
        else if (!stall)        imemfault <= !instmisalign && (pc_idx >= IMEM_WORD);
    end

endmodule
