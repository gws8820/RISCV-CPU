timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module memory_ram(
    input   logic           clk,
    input   memaccess_t     access,
    input   logic [31:0]    addr,
    input   logic [3:0]     wstrb,
    input   logic [31:0]    write_data,
    output  logic [31:0]    read_data
);

    logic [29:0]            addr_word;
    assign                  addr_word       = addr[31:2];

    logic [29:0]            ram_idx;
    assign                  ram_idx         = addr_word - RAM_BASE_WORD;

    (* ram_style = "block" *) logic [31:0]  ram_array [0:RAM_SIZE_WORD-1];
    
    always_ff@(posedge clk) begin
        if (access == MEM_WRITE && (ram_idx < RAM_SIZE_WORD)) begin
            if (wstrb[0]) ram_array[ram_idx][7:0]    <= write_data[7:0];
            if (wstrb[1]) ram_array[ram_idx][15:8]   <= write_data[15:8];
            if (wstrb[2]) ram_array[ram_idx][23:16]  <= write_data[23:16];
            if (wstrb[3]) ram_array[ram_idx][31:24]  <= write_data[31:24];
        end

        read_data <= (ram_idx < RAM_SIZE_WORD) ? ram_array[ram_idx] : 32'b0;
    end

endmodule
