timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module data_memory(
    input   logic           start, clk,
    input   memaccess_t     memaccess,
    input   logic [29:0]    word_addr,
    input   logic [3:0]     wstrb,
    input   logic [31:0]    wdata,
    output  logic [31:0]    rdata,
    output  logic           dmemfault
);

    (* ram_style="block" *) logic [31:0] data_mem [0:DMEM_WORD-1];

    initial begin
        foreach (data_mem[i]) begin
            data_mem[i] <= 32'b0;
        end
    end
    
    always_ff@(posedge clk) begin
        if (!start) begin
            dmemfault <= 0;
            rdata <= 32'b0;
        end
        else begin
            if (memaccess == MEM_DISABLED) begin
                dmemfault <= 0;
                rdata <= 32'b0;
            end
            else begin
                if (word_addr >= DMEM_WORD) begin // Byte Aligned
                    dmemfault <= 1;
                    rdata <= 32'b0;
                end
                else begin
                    dmemfault <= 0;
                    rdata <= data_mem[word_addr];

                    if (memaccess == MEM_WRITE) begin
                        if (wstrb[3]) data_mem[word_addr][31:24] <= wdata[31:24];
                        if (wstrb[2]) data_mem[word_addr][23:16] <= wdata[23:16];
                        if (wstrb[1]) data_mem[word_addr][15:8]  <= wdata[15:8];
                        if (wstrb[0]) data_mem[word_addr][7:0]   <= wdata[7:0];
                    end
                end
            end
        end
    end

endmodule