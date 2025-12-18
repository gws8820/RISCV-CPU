timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;
import riscv_defines::*;

module uart_baud_gen(
    input   logic       rstn,
    input   logic       clk,
    output  logic       sample_tick,
    output  logic       baud_tick
);

    localparam  SAMPLE_CNT                      = CLK_FREQ / (BAUD_RATE * OVERSAMPLE_RATE);
    logic       [$clog2(SAMPLE_CNT)-1:0]        sample_counter;

    logic       [$clog2(OVERSAMPLE_RATE)-1:0]   baud_counter;


    always_ff@(posedge clk) begin
        if (!rstn) begin
            sample_tick             <= 0;
            sample_counter          <= 0;

            baud_tick               <= 0;
            baud_counter            <= 0;
        end
        else begin
            if (sample_counter == SAMPLE_CNT - 1) begin
                sample_tick         <= 1;
                sample_counter      <= 0;

                if (baud_counter == OVERSAMPLE_RATE - 1) begin
                    baud_tick       <= 1;
                    baud_counter    <= 0;
                end
                else begin
                    baud_tick       <= 0;
                    baud_counter    <= baud_counter + 1;
                end
            end
            else begin
                sample_tick         <= 0;
                sample_counter      <= sample_counter + 1;

                baud_tick           <= 0;
            end
        end
    end

endmodule