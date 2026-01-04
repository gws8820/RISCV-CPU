timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module load_store_unit (
    input   logic           start, clk,
    input   logic [31:0]    addr, data,
    input   memaccess_t     memaccess,
    input   mask_mode_t     mask_mode,
    output  logic [31:0]    rdata_ext,
    output  logic           dmemfault,
    
    output  logic           print_en,
    output  logic [31:0]    print_data
);
    
    logic [3:0]             wstrb;
    logic [31:0]            wdata, rdata;
    
    store_align_unit store_align (
        .memaccess          (memaccess),
        .data               (data),
        .byte_offset        (addr[1:0]),
        .mask_mode          (mask_mode),
        .wstrb              (wstrb),
        .wdata              (wdata)
    );
    
    data_memory data_mem (
        .start              (start),
        .clk                (clk),
        .memaccess          (memaccess),
        .word_addr          (addr[31:2]),
        .wstrb              (wstrb),
        .wdata              (wdata),
        .rdata              (rdata),
        .dmemfault          (dmemfault),
        
        .print_en           (print_en),
        .print_data         (print_data)
    );
    
    logic [1:0]             byte_offset_reg;
    memaccess_t             memaccess_reg;
    mask_mode_t             mask_mode_reg;
    
    always_ff @(posedge clk) begin
        if (!start) begin
            byte_offset_reg <= '0;
            memaccess_reg   <= MEM_DISABLED;
            mask_mode_reg   <= MASK_WORD;
        end
        else begin
            byte_offset_reg <= addr[1:0];
            memaccess_reg   <= memaccess;
            mask_mode_reg   <= mask_mode;
        end
    end
    
    load_extend_unit load_extend (
        .memaccess          (memaccess_reg),
        .rdata              (rdata),
        .byte_offset        (byte_offset_reg),
        .mask_mode          (mask_mode_reg),
        .rdata_ext          (rdata_ext)
    );

endmodule