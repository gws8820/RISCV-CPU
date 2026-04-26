timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module memory_rom(
    input   logic                   start, clk,
    memory_init_interface.sink      init,

    input   logic [31:0]            fetch_addr,
    output  logic                   fetch_access_fault,
    output  inst_t                  fetch_inst,

    input   logic                   load_enable,
    input   logic [31:0]            load_addr,
    output  logic [31:0]            load_data
);

    logic [29:0]                    init_word;
    logic [29:0]                    init_idx;
    logic                           init_hit;
    
    logic [29:0]                    fetch_word;
    logic [29:0]                    fetch_idx;
    logic                           fetch_hit;

    logic [29:0]                    load_word;
    logic [29:0]                    load_idx;
    logic                           load_hit;

    assign init_word                = init.write_addr[31:2];
    assign init_idx                 = init_word - ROM_BASE_WORD;
    assign init_hit                 = (init_word >= ROM_BASE_WORD) && (init_idx < ROM_SIZE_WORD);

    assign fetch_word               = fetch_addr[31:2];
    assign fetch_idx                = fetch_word - ROM_BASE_WORD;
    assign fetch_hit                = (fetch_word >= ROM_BASE_WORD) && (fetch_idx < ROM_SIZE_WORD);

    assign load_word                = load_addr[31:2];
    assign load_idx                 = load_word - ROM_BASE_WORD;
    assign load_hit                 = (load_word >= ROM_BASE_WORD) && (load_idx < ROM_SIZE_WORD);

    (* ram_style="block", cascade_height=1 *) logic [31:0] rom_array [0:ROM_SIZE_WORD-1];

    `ifndef SYNTHESIS
        initial $readmemh("firmware.hex", rom_array);
    `endif

    always_ff@(posedge clk) begin
        fetch_inst                  <= fetch_hit ? inst_t'(rom_array[fetch_idx]) : '0;
    end

    assign fetch_access_fault       = start && !fetch_hit;

    always_ff@(posedge clk) begin
        if (init.write_enable && init_hit) begin
            rom_array[init_idx]     <= init.write_data;
        end

        if (!start) begin
            load_data               <= '0;
        end
        else if (init.write_enable) begin
            load_data               <= 32'b0;
        end
        else if (load_enable) begin
            load_data               <= load_hit ? rom_array[load_idx] : 32'b0;
        end
        else begin
            load_data               <= 32'b0;
        end
    end

endmodule
