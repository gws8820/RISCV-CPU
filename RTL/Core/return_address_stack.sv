timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module return_address_stack (
    input   logic           start,
    input   logic           clk,

    output  logic           empty,
    output  logic           full,

    input   logic           push,
    input   logic [31:0]    push_addr,

    input   logic           pop,
    output  logic [31:0]    pop_addr
);

    (* ram_style="distributed" *) logic [31:0] ras_mem [0:RAS_SIZE-1];
    logic [RAS_PTR_BITS:0] pointer; // 0..RAS_SIZE
    
    initial begin
        foreach (ras_mem[i]) begin
            ras_mem[i] <= '0;
        end
    end

    always_comb begin
        empty    = (pointer == '0);
        full     = (pointer == RAS_SIZE);

        if (empty) begin
            pop_addr = 32'b0;
        end
        else begin
            pop_addr = ras_mem[pointer - 1];
        end
    end

    always_ff @(posedge clk) begin
        if (!start) begin
            pointer <= '0;
        end
        else begin
            if (push && pop && !empty) begin
                ras_mem[pointer - 1] <= push_addr;
            end
            else if (push && !full) begin
                ras_mem[pointer] <= push_addr;
                pointer          <= pointer + 1;
            end
            else if (pop && !empty) begin
                pointer          <= pointer - 1;
            end
        end
    end

endmodule