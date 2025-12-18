timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module instruction_memory(
    input   logic           start, clk,
    input   logic [31:0]    pc,
    input   logic           instmisalign,
    output  logic           imemfault,
    output  inst_t          inst,

    input   logic           prog_en,
    input   logic [31:0]    prog_addr,
    input   logic [31:0]    prog_data
);

    logic [29:0] pc_word;
    assign pc_word = pc[31:2];

    logic [29:0] prog_word;
    assign prog_word = prog_addr[31:2];

    (* ram_style="block" *) logic [31:0] inst_mem [0:IMEM_WORD-1];

    `ifndef SYNTHESIS
        // Simulation only
        initial begin
            $readmemh("program.hex", inst_mem);
        end
    `else
        // FPGA & Synthesis
    `endif
    
    always_ff@(posedge clk) begin
        if (prog_en && (prog_word < IMEM_WORD)) begin
            inst_mem[prog_word] <= prog_data;
        end
    end
    
    always_ff@(posedge clk) begin
        if (!start) begin
            imemfault <= 0;
            inst <= INST_NOP;
        end
        else begin
            if (instmisalign) begin
                imemfault <= 0;
                inst <= INST_NOP;
            end
            else begin
                if (pc_word >= IMEM_WORD) begin // Word Aligned
                    imemfault <= 1;
                    inst <= INST_NOP;
                end
                else begin
                    imemfault <= 0;
                    inst <= inst_mem[pc_word];
                end
            end
        end
    end
endmodule