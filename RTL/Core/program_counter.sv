timeunit 1ns;
timeprecision 1ps;

module program_counter(
    input   logic           start, clk,
    input   logic           stall,
    input   logic [31:0]    pc_next,
    output  logic [31:0]    pc
);

    always_ff@(posedge clk) begin
        if(!start)
            pc <= 32'b0;
        else if (stall) begin
            pc <= pc;
        end
        else begin
            pc <= pc_next;
        end
    end

endmodule
