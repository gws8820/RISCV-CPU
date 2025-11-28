timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module load_store_unit (
    input   logic           start, clk,
    input   logic [31:0]    addr, data,
    input   memaccess_t     memaccess,
    input   mask_mode_t     mask_mode,
    output  logic [31:0]    rdata_ext,
    output  logic           dmemfault
);
    
    logic [3:0]     wstrb;
    logic [31:0]    wdata, rdata;
    
    store_align_unit store_align (
        .memaccess  (memaccess),
        .data       (data),
        .addr_offset(addr[1:0]),
        .mask_mode  (mask_mode),
        .wstrb      (wstrb),
        .wdata      (wdata)
    );
    
    data_memory data_mem (
        .start      (start),
        .clk        (clk),
        .memaccess  (memaccess),
        .word_addr  (addr[31:2]),
        .wstrb      (wstrb),
        .wdata      (wdata),
        .rdata      (rdata),
        .dmemfault  (dmemfault)
    );
    
    logic [1:0]     addr_offset_reg;
    memaccess_t     memaccess_reg;
    mask_mode_t     mask_mode_reg;
    
    always_ff @(posedge clk) begin
        addr_offset_reg <= addr[1:0];
        memaccess_reg   <= memaccess;
        mask_mode_reg   <= mask_mode;
    end
    
    load_extend_unit load_extend (
        .memaccess  (memaccess_reg),
        .rdata      (rdata),
        .addr_offset(addr_offset_reg),
        .mask_mode  (mask_mode_reg),
        .rdata_ext  (rdata_ext)
    );

endmodule