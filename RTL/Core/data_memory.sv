timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module data_memory(
    input   logic           start, clk,
    input   memaccess_t     memaccess,
    input   logic [31:0]    mem_addr,
    input   logic [3:0]     wstrb,
    input   logic [31:0]    wdata,
    output  logic [31:0]    rdata,
    output  logic           dmemfault,

    input   logic           prog_en,
    input   logic [31:0]    prog_addr,
    input   logic [31:0]    prog_data,

    output  logic           boot_en,
    output  logic           exit_en,
    output  logic [7:0]     exit_code,
    output  logic           print_en,
    output  logic [31:0]    print_data
);

    localparam              offset      = DMEM_ADDR[31:2];

    logic                   boot_flag;
    logic [29:0]            dmem_idx, prog_idx, print_idx;

    assign                  dmem_idx    = mem_addr[31:2]    - offset;
    assign                  prog_idx    = prog_addr[31:2]   - offset;
    assign                  print_idx   = PRINT_ADDR[31:2]  - offset;

    (* ram_style="block", cascade_height=1, ram_decomp="power" *) logic [31:0] data_mem [0:DMEM_WORD-1];

    `ifndef SYNTHESIS
        logic [31:0] raw_mem [0:(offset + DMEM_WORD - 1)];
        initial begin
            foreach (raw_mem[i]) raw_mem[i] = 32'h0;
            $readmemh("dhrystone.hex", raw_mem);
            
            for (int i = 0; i < DMEM_WORD; i++)
                data_mem[i] = raw_mem[offset + i];
        end
    `endif

    always_ff@(posedge clk) begin
        if (prog_en && (prog_idx < DMEM_WORD)) begin
            data_mem[prog_idx] <= prog_data;
        end
    end
    
    // DMEM Access
    always_ff@(posedge clk) begin
        rdata <= data_mem[dmem_idx];

        if (memaccess == MEM_WRITE && (dmem_idx < DMEM_WORD)) begin
            if (wstrb[3]) data_mem[dmem_idx][31:24] <= wdata[31:24];
            if (wstrb[2]) data_mem[dmem_idx][23:16] <= wdata[23:16];
            if (wstrb[1]) data_mem[dmem_idx][15:8]  <= wdata[15:8];
            if (wstrb[0]) data_mem[dmem_idx][7:0]   <= wdata[7:0];
        end

    end

    // Print & Fault Detection
    always_ff@(posedge clk) begin
        boot_en                 <= 0;
        exit_en                 <= 0;
        print_en                <= 0;

        if (!start) begin
            dmemfault           <= 0;
            boot_flag           <= 0;
            exit_code           <= 8'd0;
            print_data          <= 32'b0;
        end
        else begin
            if (!boot_flag) begin
                boot_en         <= 1;
                boot_flag       <= 1;
            end
            else if (memaccess == MEM_WRITE && dmem_idx == print_idx) begin
                if (wdata[8]) begin
                    exit_en     <= 1;
                    exit_code   <= wdata[7:0];
                end
                else begin
                    print_en    <= 1;
                    print_data  <= wdata;
                end
            end

            dmemfault <= (memaccess != MEM_DISABLED)
                      && (dmem_idx != print_idx)
                      && (dmem_idx >= DMEM_WORD);
        end
    end

endmodule
