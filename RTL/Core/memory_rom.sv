timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module memory_rom(
    input   logic                   clk,
    memory_init_interface.sink      init,

    input   logic [31:0]            fetch_addr,
    output  inst_t                  fetch_inst,

    input   logic                   read_enable,
    input   logic [31:0]            read_addr,
    output  logic [31:0]            read_data
);

    logic [29:0]                    init_idx;
    logic                           init_hit;
    
    logic [29:0]                    fetch_idx;
    logic                           fetch_hit;
    
    logic [29:0]                    read_idx;
    logic                           read_hit;

    assign init_idx                 = init.write_addr[31:2] - ROM_BASE_WORD;
    assign init_hit                 = init_idx < ROM_SIZE_WORD;

    assign fetch_idx                = fetch_addr[31:2] - ROM_BASE_WORD;
    assign fetch_hit                = fetch_idx < ROM_SIZE_WORD;

    assign read_idx                 = read_addr[31:2] - ROM_BASE_WORD;
    assign read_hit                 = read_idx < ROM_SIZE_WORD;

    (* ram_style="block", cascade_height=1 *) logic [31:0] rom_array [0:ROM_SIZE_WORD-1];

    `ifndef SYNTHESIS
        initial $readmemh("firmware.hex", rom_array);
    `endif

    always_ff@(posedge clk) begin
        fetch_inst                  <= fetch_hit ? inst_t'(rom_array[fetch_idx]) : '0;
    end

    always_ff@(posedge clk) begin
        // Write
        if (init.write_enable && init_hit) begin
            rom_array[init_idx]     <= init.write_data;
        end

        // Read
        read_data                   <= (read_enable && read_hit) ? rom_array[read_idx] : 32'b0;
    end

endmodule
