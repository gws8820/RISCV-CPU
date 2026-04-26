timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_mem2 (
    input   logic                   start, clk,

    input   control_bus_t           control_bus_m1,
    input   logic [4:0]             rd_m1,
    input   loadsrc_t               load_source_m1,
    input   logic [1:0]             byte_offset_m1,
    input   logic [31:0]            result_m1,
    input   logic [31:0]            ram_read_data,
    input   logic [31:0]            rom_load_data,
    input   logic                   mmio_in_valid,
    input   logic [7:0]             mmio_in_data,

    output  control_bus_t           control_bus_m2,
    output  logic [4:0]             rd_m2,
    output  logic [31:0]            memresult_m2,
    output  logic [31:0]            result_m2,

    input   hazard_res_t            hazard_res
);

    logic [31:0]                    load_data_m2;
    loadsrc_t                       load_source_m2;
    logic [1:0]                     byte_offset_m2;
    logic                           mmio_in_valid_m2;
    logic [7:0]                     mmio_in_data_m2;

    always_ff@(posedge clk) begin
        if (!start) begin
            control_bus_m2          <= '0;
            load_source_m2          <= LOAD_ZERO;
            mmio_in_valid_m2        <= 0;
            mmio_in_data_m2         <= 8'b0;
        end
        else begin
            priority if (hazard_res.flush_m2) begin
                control_bus_m2      <= '0;
                load_source_m2      <= LOAD_ZERO;
                mmio_in_valid_m2    <= 0;
                mmio_in_data_m2     <= 8'b0;
            end
            else begin
                control_bus_m2      <= control_bus_m1;
                rd_m2               <= rd_m1;
                result_m2           <= result_m1;
                byte_offset_m2      <= byte_offset_m1;
                load_source_m2      <= load_source_m1;
                mmio_in_valid_m2    <= mmio_in_valid;
                mmio_in_data_m2     <= mmio_in_data;
            end
        end
    end

    always_comb begin
        unique case (load_source_m2)
            LOAD_RAM:               load_data_m2 = ram_read_data;
            LOAD_ROM:               load_data_m2 = rom_load_data;
            LOAD_INPUT:             load_data_m2 = mmio_in_valid_m2 ? {24'b0, mmio_in_data_m2} : 32'hFFFF_FFFF;
            default:                load_data_m2 = 32'b0;
        endcase
    end

    // Load Extend Unit
    load_extend_unit load_extend_unit (
        .memaccess                  (control_bus_m2.memaccess),
        .rdata                      (load_data_m2),
        .byte_offset                (byte_offset_m2),
        .mask_mode                  (control_bus_m2.funct3.mask_mode),
        .rdata_ext                  (memresult_m2)
    );

endmodule
