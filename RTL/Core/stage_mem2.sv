timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_mem2 (
    input   logic                   start, clk,

    input   control_signal_t        control_signal_m1,
    input   logic [31:0]            pc_m1,
    input   logic [31:0]            pcplus4_m1,
    input   logic [4:0]             rd_m1,
    input   logic [31:0]            loaddata_m1,
    input   logic [1:0]             byte_offset_m1,
    input   logic [31:0]            result_m1,

    output  control_signal_t        control_signal_m2,
    output  logic [4:0]             rd_m2,
    output  logic [31:0]            memresult_m2,
    output  logic [31:0]            result_m2,

    hazard_interface.requester      hazard_bus
);

    logic                           mem2_valid;
    
    logic [31:0]                    pc_m2;
    logic [31:0]                    pcplus4_m2;

    logic [31:0]                    loaddata_m2;
    logic [1:0]                     byte_offset_m2;

    always_ff@(posedge clk) begin
        if (!start) begin
            mem2_valid              <= 0;
            control_signal_m2       <= '0;
            pc_m2                   <= 32'b0;
            pcplus4_m2              <= 32'b0;
            rd_m2                   <= 5'b0;
            result_m2               <= 32'b0;
            byte_offset_m2          <= 2'b0;
        end
        else begin
            priority if (hazard_bus.res.flush_m2) begin
                mem2_valid          <= 0;
                control_signal_m2   <= '0;
                rd_m2               <= 5'b0;
            end
            else begin
                mem2_valid          <= 1;
                control_signal_m2   <= control_signal_m1;
                pc_m2               <= pc_m1;
                pcplus4_m2          <= pcplus4_m1;
                rd_m2               <= rd_m1;
                result_m2           <= result_m1;
                byte_offset_m2      <= byte_offset_m1;
            end
        end
    end

    always_comb begin
        loaddata_m2                 = loaddata_m1;
    end

    // Load Extend Unit
    load_extend_unit load_extend_unit (
        .memaccess                  (control_signal_m2.memaccess),
        .rdata                      (loaddata_m2),
        .byte_offset                (byte_offset_m2),
        .mask_mode                  (control_signal_m2.funct3.mask_mode),
        .rdata_ext                  (memresult_m2)
    );

    // Hazard Packet
    always_comb begin
        hazard_bus.req.rd_m2        = rd_m2;
        hazard_bus.req.regwrite_m2  = control_signal_m2.regwrite;
        hazard_bus.req.memaccess_m2 = control_signal_m2.memaccess;
    end

endmodule