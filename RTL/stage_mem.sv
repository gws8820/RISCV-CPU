timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_mem (
    input   logic                   start, clk,
    input   control_signal_t        control_signal_e,
    input   logic [31:0]            pc_e,
    input   logic [31:0]            pcplus4_e,
    input   logic [4:0]             rs2_e, rd_e,
    input   logic [31:0]            aluresult_e,
    input   logic [31:0]            storedata_e,
    input   logic [31:0]            csr_wdata_e,

    input   logic [31:0]            result_w,

    output  control_signal_t        control_signal_m,
    output  logic [31:0]            pc_m,
    output  logic [31:0]            pcplus4_m,
    output  logic [4:0]             rs2_m, rd_m,
    output  logic [31:0]            csr_wdata_m,
    output  logic [31:0]            memresult_m,
    output  logic [31:0]            result_m,

    input   trap_res_t              trap_res,
    input   trap_req_t              trap_req_e,
    output  trap_req_t              trap_req_m,

    input   logic [31:0]            csr_result,

    hazard_interface.requester      hazard_bus,
    
    output  logic                   print_en,
    output  logic [31:0]            print_data
);

    trap_flag_t                     trap_flag;
    trap_req_t                      trap_req_prev;

    logic [31:0]                    aluresult_m;
    logic [31:0]                    storedata_m;
    
    always_ff@(posedge clk) begin
        if (!start) begin
            control_signal_m        <= '0;
            pc_m                    <= 32'b0;
            pcplus4_m               <= 32'b0;
            aluresult_m             <= 32'b0;
            storedata_m             <= 32'b0;
            csr_wdata_m             <= 32'b0;
            rs2_m                   <= 5'b0;
            rd_m                    <= 5'b0;
            
            trap_req_prev           <= '0;
        end
        else begin
            priority if (hazard_bus.res.flush_m) begin
                control_signal_m    <= '0;
                pc_m                <= 32'b0;
                pcplus4_m           <= 32'b0;
                aluresult_m         <= 32'b0;
                storedata_m         <= 32'b0;
                csr_wdata_m         <= 32'b0;
                rs2_m               <= 5'b0;
                rd_m                <= 5'b0;

                trap_req_prev       <= '0;
            end
            else begin
                control_signal_m    <= control_signal_e;
                pc_m                <= pc_e;
                pcplus4_m           <= pcplus4_e;
                aluresult_m         <= aluresult_e;
                storedata_m         <= storedata_e;
                csr_wdata_m         <= csr_wdata_e;
                rs2_m               <= rs2_e;
                rd_m                <= rd_e;

                trap_req_prev       <= trap_req_e;
            end
        end
    end

    // LSU Source Selector
    logic [31:0] store_data;

    always_comb begin
        unique case(hazard_bus.res.forward_mem)
            0:                      store_data = storedata_m;
            1:                      store_data = result_w;
            default:                store_data = storedata_m;
        endcase
    end
    
    // Load Store Unit
    logic kill_m;
    
    load_store_unit load_store_unit (
        .start                      (start),
        .clk                        (clk),
        .addr                       (aluresult_m),
        .data                       (store_data),
        .memaccess                  (kill_m ? MEM_DISABLED : control_signal_m.memaccess), // PREVENT MEMORY ACCESS IF TRAP OCCURRED
        .mask_mode                  (control_signal_m.funct3.mask_mode),
        .rdata_ext                  (memresult_m),
        .dmemfault                  (trap_flag.dmemfault),
        
        .print_en                   (print_en),
        .print_data                 (print_data)
    );
    
    // Hazard Packet
    always_comb begin
        hazard_bus.req.rs2_m        = rs2_m;
        hazard_bus.req.rd_m         = rd_m;
        hazard_bus.req.memaccess_m  = control_signal_m.memaccess;
        hazard_bus.req.regwrite_m   = control_signal_m.regwrite;
        
        hazard_bus.req.flushflag    = trap_res.flushflag || control_signal_m.fencei;
    end
    
    // Trap Packet
    always_comb begin
        trap_flag.instillegal       = 0;
        trap_flag.instmisalign      = 0;
        trap_flag.imemfault         = 0;
        trap_flag.datamisalign      = 0;

        if (trap_req_prev.valid) begin
            kill_m                  = 1;
            trap_req_m              = trap_req_prev;
        end
        else begin
            kill_m                  = 0;
            
            if (trap_flag.dmemfault) begin
                trap_req_m.valid    = 1;
                trap_req_m.mode     = TRAP_ENTER;
                trap_req_m.cause    = (control_signal_m.memaccess == MEM_WRITE) ? CAUSE_STORE_ACCESS_FAULT : CAUSE_LOAD_ACCESS_FAULT;
                trap_req_m.pc       = pc_m;
                trap_req_m.tval     = aluresult_m;
            end
            else trap_req_m         = '0;
        end
    end

    // Pre-Result Selector
    always_comb begin
        unique case(control_signal_m.resultsrc)
            RESULT_ALU:             result_m = aluresult_m;
            RESULT_PCPLUS4:         result_m = pcplus4_m;
            RESULT_CSR:             result_m = csr_result;
            default:                result_m = aluresult_m;
        endcase
    end
endmodule