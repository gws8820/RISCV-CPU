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
    output  logic [31:0]            loaddata_m1,
    output  logic [1:0]             byte_offset_m1,
    output  logic [31:0]            result_m1,

    input   trap_res_t              trap_res,
    input   trap_req_t              trap_req_e,
    output  trap_req_t              trap_req_m1,
    output  logic                   datamisalign,
    output  logic                   dmemfault,
    input   logic [31:0]            csr_result,
    input   hazard_res_t            hazard_res,
    
    output  logic                   print_en,
    output  logic [31:0]            print_data
);

    trap_req_t                      trap_req_prev;

    logic [31:0]                    pc_m1;
    logic [31:0]                    pcplus4_m1;
    logic [31:0]                    storedata_m1;
    
    logic                           alu_valid_m1, mul_valid_m1, div_valid_m1;
    logic [31:0]                    aluresult_m1, mulresult_m1, divresult_m1;
    
    logic [31:0]                    exec_result;

    always_ff@(posedge clk) begin
        if (!start) begin
            control_bus_m1          <= '0;
            alu_valid_m1            <= 0;
            mul_valid_m1            <= 0;
            div_valid_m1            <= 0;

            trap_req_prev           <= '0;
        end
        else begin
            priority if (hazard_res.flush_m1) begin
                control_bus_m1      <= '0;
                alu_valid_m1        <= 0;
                mul_valid_m1        <= 0;
                div_valid_m1        <= 0;
                trap_req_prev       <= '0;
            end
            else if (!hazard_res.stall_m1) begin
                control_bus_m1      <= control_bus_e;
                pc_m1               <= pc_e;
                pcplus4_m1          <= pcplus4_e;

                alu_valid_m1        <= alu_valid;
                mul_valid_m1        <= mul_valid;
                div_valid_m1        <= div_valid;
                aluresult_m1        <= aluresult_e;
                mulresult_m1        <= mulresult_e;
                divresult_m1        <= divresult_e;

                storedata_m1        <= storedata_e;
                csr_wdata_m1        <= csr_wdata_e;
                rs2_m1              <= rs2_e;
                rd_m1               <= rd_e;

                trap_req_prev       <= trap_req_e;
            end
        end
    end

    // Exec Result Selector
    always_comb begin
        priority case (1)
            mul_valid_m1:           exec_result = mulresult_m1;
            div_valid_m1:           exec_result = divresult_m1;
            alu_valid_m1:           exec_result = aluresult_m1;
            default:                exec_result = 32'b0;
        endcase
    end
    
    // Address Misalign Checker
    lsu_misalign_checker lsu_misalign_checker (
        .aluresult                  (exec_result),
        .memaccess                  (control_bus_m1.memaccess),
        .mask_mode                  (control_bus_m1.funct3.mask_mode),
        .datamisalign               (datamisalign)
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
    logic                           kill_mem;
    memaccess_t                     memaccess_eff;
    assign                          memaccess_eff = kill_mem ? MEM_DISABLED : control_bus_m1.memaccess;

    logic [3:0]                     wstrb;
    logic [31:0]                    wdata;
    
    // Store Align Unit
    logic [29:0]    word_addr;
    assign          {word_addr, byte_offset_m1} = exec_result;

    store_align_unit store_align_unit (
        .memaccess                  (memaccess_eff),
        .data                       (store_data),
        .byte_offset                (byte_offset_m1),
        .mask_mode                  (control_bus_m1.funct3.mask_mode),
        .wstrb                      (wstrb),
        .wdata                      (wdata)
    );
    
    // Data Memory
    data_memory data_memory (
        .start                      (start),
        .clk                        (clk),
        .memaccess                  (memaccess_eff),
        .word_addr                  (word_addr),
        .wstrb                      (wstrb),
        .wdata                      (wdata),
        .rdata                      (loaddata_m1),
        .dmemfault                  (dmemfault),
        
        .print_en                   (print_en),
        .print_data                 (print_data)
    );
    
    // Trap Packet
    always_comb begin
        if (trap_req_prev.valid) begin
            kill_mem                = 1;
            trap_req_m1             = trap_req_prev;
        end
        else begin
            priority if (datamisalign) begin
                kill_mem            = 1;

                trap_req_m1.valid   = 1;
                trap_req_m1.mode    = TRAP_ENTER;
                trap_req_m1.cause   = (control_bus_m1.memaccess == MEM_WRITE) ? CAUSE_STORE_ADDR_MISALIGN : CAUSE_LOAD_ADDR_MISALIGN;
                trap_req_m1.pc      = pc_m1;
                trap_req_m1.tval    = exec_result;
            end
            else if (dmemfault) begin
                kill_mem            = 0;

                trap_req_m1.valid   = 1;
                trap_req_m1.mode    = TRAP_ENTER;
                trap_req_m1.cause   = (control_bus_m1.memaccess == MEM_WRITE) ? CAUSE_STORE_ACCESS_FAULT : CAUSE_LOAD_ACCESS_FAULT;
                trap_req_m1.pc      = pc_m1;
                trap_req_m1.tval    = exec_result;
            end
            else begin
                kill_mem            = 0;
                trap_req_m1         = '0;
            end
        end
    end

    // Pre-Result Selector
    always_comb begin
        unique case(control_bus_m1.resultsrc)
            RESULT_ALU:             result_m1 = exec_result;
            RESULT_PCPLUS4:         result_m1 = pcplus4_m1;
            RESULT_CSR:             result_m1 = csr_result;
            default:                result_m1 = exec_result;
        endcase
    end
endmodule