timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_mem1 (
    input   logic                   start, clk,
    input   control_bus_t           control_bus_e,
    input   logic [31:0]            pc_e,
    input   logic [31:0]            pcplus4_e,
    input   logic [4:0]             rs2_e, rd_e,

    input   logic                   alu_valid, mul_valid, div_valid,
    input   logic [31:0]            aluresult_e, mulresult_e, divresult_e,
    input   logic [31:0]            storedata_e,
    input   logic [31:0]            csr_wdata_e,

    input   logic [31:0]            result_w,

    output  control_bus_t           control_bus_m1,
    output  logic [4:0]             rd_m1,
    output  logic [4:0]             rs2_m1,
    output  logic [31:0]            csr_wdata_m1,
    output  loadsrc_t               load_source_m1,
    output  logic [1:0]             byte_offset_m1,
    output  logic [31:0]            result_m1,

    output  logic                   rom_load_enable,
    output  logic [31:0]            rom_load_addr,

    output  memaccess_t             ram_access,
    output  logic [31:0]            ram_addr,
    output  logic [3:0]             ram_wstrb,
    output  logic [31:0]            ram_write_data,

    input   trap_req_t              trap_req_e,
    output  trap_req_t              trap_req_m1,
    input   logic [31:0]            csr_result,
    input   hazard_res_t            hazard_res,

    mmio_out_interface.source       mmio_out,
    mmio_in_interface.sink          mmio_in
);

    trap_req_t                      trap_req_prev;

    logic [31:0]                    pc_m1;
    logic [31:0]                    pcplus4_m1;
    logic [31:0]                    storedata_m1;
    
    logic [31:0]                    exec_result_m1;
    logic                           data_addr_misaligned;
    logic                           data_access_fault;

    always_ff@(posedge clk) begin
        if (!start) begin
            control_bus_m1          <= '0;
            exec_result_m1          <= 32'b0;

            trap_req_prev           <= '0;
        end
        else begin
            if (hazard_res.flush_m1) begin
                control_bus_m1      <= '0;
                exec_result_m1      <= 32'b0;
                trap_req_prev       <= '0;
            end
            else begin
                control_bus_m1      <= control_bus_e;
                pc_m1               <= pc_e;
                pcplus4_m1          <= pcplus4_e;

                priority case (1)
                    mul_valid:      exec_result_m1 <= mulresult_e;
                    div_valid:      exec_result_m1 <= divresult_e;
                    alu_valid:      exec_result_m1 <= aluresult_e;
                    default:        exec_result_m1 <= 32'b0;
                endcase

                storedata_m1        <= storedata_e;
                csr_wdata_m1        <= csr_wdata_e;
                rs2_m1              <= rs2_e;
                rd_m1               <= rd_e;

                trap_req_prev       <= trap_req_e;
            end
        end
    end

    // Data Alignment Checker
    data_alignment_checker data_alignment_checker (
        .addr                       (exec_result_m1),
        .memaccess                  (control_bus_m1.memaccess),
        .mask_mode                  (control_bus_m1.funct3.mask_mode),
        .data_addr_misaligned       (data_addr_misaligned)
    );

    // Store Data Selector
    logic [31:0] store_data;

    always_comb begin
        unique case(hazard_res.forward_m1)
            0:                      store_data = storedata_m1;
            1:                      store_data = result_w;
            default:                store_data = storedata_m1;
        endcase
    end
    
    // Load Store Unit
    memaccess_t                     data_access;
    logic [29:0]                    data_word;
    logic [29:0]                    rom_idx;
    logic [29:0]                    ram_idx;
    logic                           rom_hit;
    logic                           ram_hit;
    logic                           mmio_print_hit;
    logic                           mmio_input_hit;
    logic                           boot_flag;

    assign data_access              = (trap_req_prev.valid || data_addr_misaligned) ? MEM_DISABLED : control_bus_m1.memaccess;

    assign data_word                = exec_result_m1[31:2];
    assign rom_idx                  = data_word - ROM_BASE_WORD;
    assign ram_idx                  = data_word - RAM_BASE_WORD;
    assign rom_hit                  = (data_word >= ROM_BASE_WORD) && (rom_idx < ROM_SIZE_WORD);
    assign ram_hit                  = (data_word >= RAM_BASE_WORD) && (ram_idx < RAM_SIZE_WORD);
    assign mmio_print_hit           = (data_word == MMIO_PRINT_WORD);
    assign mmio_input_hit           = (data_word == MMIO_INPUT_WORD);

    assign rom_load_enable          = (data_access == MEM_READ) && rom_hit;
    assign rom_load_addr            = exec_result_m1;

    assign data_access_fault        = (data_access != MEM_DISABLED)
                                    && !ram_hit
                                    && !(rom_hit && (data_access == MEM_READ))
                                    && !(mmio_print_hit && (data_access == MEM_WRITE))
                                    && !(mmio_input_hit && (data_access == MEM_READ));
    
    // Store Align Unit
    assign byte_offset_m1 = exec_result_m1[1:0];

    store_align_unit store_align_unit (
        .memaccess                  (data_access),
        .data                       (store_data),
        .byte_offset                (byte_offset_m1),
        .mask_mode                  (control_bus_m1.funct3.mask_mode),
        .wstrb                      (ram_wstrb),
        .wdata                      (ram_write_data)
    );

    assign ram_access               = ram_hit ? data_access : MEM_DISABLED;
    assign ram_addr                 = exec_result_m1;

    always_comb begin
        unique case (1)
            (data_access == MEM_READ) && ram_hit:         load_source_m1 = LOAD_RAM;
            (data_access == MEM_READ) && rom_hit:         load_source_m1 = LOAD_ROM;
            (data_access == MEM_READ) && mmio_input_hit:  load_source_m1 = LOAD_INPUT;
            default:                                      load_source_m1 = LOAD_ZERO;
        endcase
    end

    always_ff@(posedge clk) begin
        mmio_out.boot_valid         <= 0;
        mmio_out.exit_valid         <= 0;
        mmio_out.print_valid        <= 0;
        mmio_in.ready               <= 0;

        if (!start) begin
            boot_flag               <= 0;
            mmio_out.exit_code      <= 8'd0;
            mmio_out.print_data     <= 32'b0;
        end
        else begin
            mmio_in.ready           <= mmio_in.valid && (data_access == MEM_READ) && mmio_input_hit;

            if (!boot_flag) begin
                mmio_out.boot_valid <= 1;
                boot_flag           <= 1;
            end
            else if ((data_access == MEM_WRITE) && mmio_print_hit) begin
                if (ram_write_data[8]) begin
                    mmio_out.exit_valid <= 1;
                    mmio_out.exit_code  <= ram_write_data[7:0];
                end
                else begin
                    mmio_out.print_valid <= 1;
                    mmio_out.print_data  <= ram_write_data;
                end
            end
        end
    end
    
    // Trap Packet
    always_comb begin
        if (trap_req_prev.valid) begin
            trap_req_m1             = trap_req_prev;
        end
        else begin
            priority if (data_addr_misaligned) begin
                trap_req_m1.valid   = 1;
                trap_req_m1.mode    = TRAP_ENTER;
                trap_req_m1.cause   = (control_bus_m1.memaccess == MEM_WRITE) ? CAUSE_STORE_AMO_ADDR_MISALIGNED : CAUSE_LOAD_ADDR_MISALIGNED;
                trap_req_m1.pc      = pc_m1;
                trap_req_m1.tval    = exec_result_m1;
            end
            else if (data_access_fault) begin
                trap_req_m1.valid   = 1;
                trap_req_m1.mode    = TRAP_ENTER;
                trap_req_m1.cause   = (control_bus_m1.memaccess == MEM_WRITE) ? CAUSE_STORE_AMO_ACCESS_FAULT : CAUSE_LOAD_ACCESS_FAULT;
                trap_req_m1.pc      = pc_m1;
                trap_req_m1.tval    = exec_result_m1;
            end
            else begin
                trap_req_m1         = '0;
            end
        end
    end

    // Pre-Result Selector
    always_comb begin
        unique case(control_bus_m1.resultsrc)
            RESULT_ALU:             result_m1 = exec_result_m1;
            RESULT_PCPLUS4:         result_m1 = pcplus4_m1;
            RESULT_CSR:             result_m1 = csr_result;
            default:                result_m1 = exec_result_m1;
        endcase
    end
endmodule
