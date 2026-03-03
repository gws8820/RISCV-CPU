timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module branch_return_address_stack (
    input   logic           start,
    input   logic           clk,

    output  logic           empty,

    input   logic           push,
    input   logic [31:0]    ret_addr,

    input   logic           pop,
    output  logic [31:0]    tos 
);

    (* ram_style="distributed" *) logic [31:0] ras_mem [0:RAS_SIZE-1];
    logic [RAS_PTR_BITS:0] pointer; // 0..RAS_SIZE
    logic                  full;

    initial begin
        foreach (ras_mem[i]) ras_mem[i] <= '0;
    end

    always_comb begin
        empty = (pointer == '0);
        full  = (pointer == RAS_SIZE);
    end

    always_ff @(posedge clk) begin
        if (!start) begin
            pointer <= '0;
            tos     <= '0;
        end
        else begin
            if (push && !full) begin
                ras_mem[pointer] <= ret_addr;
                pointer          <= pointer + 1;

                tos              <= ret_addr;
            end
            else if (pop && !empty) begin
                pointer          <= pointer - 1;
                tos              <= (pointer >= 2) ? ras_mem[pointer - 2] : 32'b0;
            end
        end
    end

endmodule
