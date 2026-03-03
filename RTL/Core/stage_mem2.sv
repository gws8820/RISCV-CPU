timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_mem2 (
    input   logic                   start, clk,

    input   control_bus_t           control_bus_m1,
    input   logic [4:0]             rd_m1,
    input   logic [31:0]            loaddata_m1,
    input   logic [1:0]             byte_offset_m1,
    input   logic [31:0]            result_m1,

    output  control_bus_t           control_bus_m2,
    output  logic [4:0]             rd_m2,
    output  logic [31:0]            memresult_m2,
    output  logic [31:0]            result_m2,

    input   hazard_res_t            hazard_res
);

    logic [31:0]                    loaddata_m2;
    logic [1:0]                     byte_offset_m2;

    always_ff@(posedge clk) begin
        if (!start) begin
            control_bus_m2          <= '0;
        end
        else begin
            priority if (hazard_res.flush_m2) begin
                control_bus_m2      <= '0;
            end
            else begin
                control_bus_m2      <= control_bus_m1;
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
        .memaccess                  (control_bus_m2.memaccess),
        .rdata                      (loaddata_m2),
        .byte_offset                (byte_offset_m2),
        .mask_mode                  (control_bus_m2.funct3.mask_mode),
        .rdata_ext                  (memresult_m2)
    );

endmodule