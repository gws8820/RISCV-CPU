timeunit 1ns;
timeprecision 1ps;

module regfile(
    input   logic           clk,
    input   logic           regwrite,
    input   logic [4:0]     waddr,
    input   logic [31:0]    wdata,
    input   logic [4:0]     raddr1, raddr2,
    output  logic [31:0]    rdata1, rdata2
);

    logic [31:0] registers [0:31];

    initial begin
        foreach (registers[i]) begin
            registers[i] <= 32'b0;
        end
    end

    logic hit1, hit2; // Data PassThrough
    always_comb begin
        hit1 = regwrite && (waddr != 5'd0) && (waddr == raddr1);
        hit2 = regwrite && (waddr != 5'd0) && (waddr == raddr2);
        
        rdata1 = (raddr1 == 5'd0) ? 32'd0
               : hit1             ? wdata
               : registers[raddr1];
               
        rdata2 = (raddr2 == 5'd0) ? 32'd0
               : hit2             ? wdata
               : registers[raddr2];
    end
    
    always_ff@(posedge clk) begin
        if (regwrite && waddr != 5'b0) begin
            registers[waddr] <= wdata;
        end
    end
    
endmodule