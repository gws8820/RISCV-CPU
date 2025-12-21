timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_ex (
    input   logic                           start, clk,

    input   logic [31:0]                    pc_d,
    input   logic [31:0]                    pcplus4_d,
    input   logic [31:0]                    pc_pred_d,
    input   logic                           pred_taken_d,
    input   inst_t                          inst_d,

    input   control_signal_t                control_signal_d,
    input   logic [4:0]                     rs1_d, rs2_d, rd_d,
    input   logic [31:0]                    rdata1_d, rdata2_d,
    input   logic [31:0]                    immext_d,

    input   logic [31:0]                    result_m, result_w,

    output  control_signal_t                control_signal_e,
    output  logic [31:0]                    pc_e,
    output  logic [31:0]                    pcplus4_e,
    output  logic [31:0]                    immext_e,
    output  logic [4:0]                     rs1_e, rs2_e, rd_e,
    output  logic [31:0]                    rdata1_e, rdata2_e,
    output  logic [31:0]                    in_a, in_b,
    output  logic [31:0]                    aluresult_e,
    output  logic [31:0]                    storedata_e,
    output  logic [31:0]                    csr_wdata_e,
    
    output  logic [31:0]                    pc_jump,
    output  logic                           cflow_valid,
    output  logic                           cflow_taken,
    output  logic                           mispredict,

    input   trap_req_t                      trap_req_d,
    output  trap_req_t                      trap_req_e,
    hazard_interface.requester              hazard_bus
);

    trap_flag_t                             trap_flag;
    trap_req_t                              trap_req_prev;

    logic [31:0]                            pc_pred_e;
    logic                                   pred_taken_e;

    always_ff@(posedge clk) begin
        if (!start) begin
            control_signal_e                <= '0;
            pc_e                            <= 32'b0;
            pcplus4_e                       <= 32'b0;
            pc_pred_e                       <= 32'b0;
            pred_taken_e                    <= 1'b0;
            rs1_e                           <= 5'b0;
            rs2_e                           <= 5'b0;
            rd_e                            <= 5'b0;
            rdata1_e                        <= 32'b0;
            rdata2_e                        <= 32'b0;
            immext_e                        <= 32'b0;

            trap_req_prev                   <= '0;
        end
        else begin
            priority if (hazard_bus.res.flush_e) begin
                control_signal_e            <= '0;
                pc_e                        <= 32'b0;
                pcplus4_e                   <= 32'b0;
                pc_pred_e                   <= 32'b0;
                pred_taken_e                <= 1'b0;
                rs1_e                       <= 5'b0;
                rs2_e                       <= 5'b0;
                rd_e                        <= 5'b0;
                rdata1_e                    <= 32'b0;
                rdata2_e                    <= 32'b0;
                immext_e                    <= 32'b0;
                
                trap_req_prev               <= '0;
            end
            else begin
                control_signal_e            <= control_signal_d;
                pc_e                        <= pc_d;
                pcplus4_e                   <= pcplus4_d;
                pc_pred_e                   <= pc_pred_d;
                pred_taken_e                <= pred_taken_d;
                rs1_e                       <= rs1_d;
                rs2_e                       <= rs2_d;
                rd_e                        <= rd_d;
                rdata1_e                    <= rdata1_d;
                rdata2_e                    <= rdata2_d;
                immext_e                    <= immext_d;
                
                trap_req_prev               <= trap_req_d;  
            end
        end
    end

    // ALU Forwarder
    logic [31:0] fwd_a, fwd_b;
    assign storedata_e = fwd_b;
    
    always_comb begin
        unique case(hazard_bus.res.forwarda_e)
            FWD_EX:                         fwd_a = rdata1_e;
            FWD_MEM:                        fwd_a = result_m;
            FWD_WB:                         fwd_a = result_w;
            default:                        fwd_a = rdata1_e;
        endcase

        unique case(hazard_bus.res.forwardb_e)
            FWD_EX:                         fwd_b = rdata2_e;
            FWD_MEM:                        fwd_b = result_m;
            FWD_WB:                         fwd_b = result_w;
            default:                        fwd_b = rdata2_e;
        endcase
    end
    
    // ALU Source Selector
    always_comb begin
        unique case(control_signal_e.alusrc_a)
            SRCA_REG:                       in_a = fwd_a;
            SRCA_PC:                        in_a = pc_e;
            SRCA_ZERO:                      in_a = 32'b0;
            default:                        in_a = fwd_a;
        endcase

        unique case(control_signal_e.alusrc_b)
            SRCB_REG:                       in_b = fwd_b;
            SRCB_IMM:                       in_b = immext_e;
            default:                        in_b = fwd_b;
        endcase
    end

    // ALU
    alu alu (
        .in_a                               (in_a),
        .in_b                               (in_b),
        .alucontrol                         (control_signal_e.alucontrol),
        .aluresult                          (aluresult_e)
    );
    
    // LSU Misalign Checker
    lsu_misalign_checker lsu_misalign_checker (
        .aluresult                          (aluresult_e),
        .memaccess                          (control_signal_e.memaccess),
        .mask_mode                          (control_signal_e.funct3.mask_mode),
        .datamisalign                       (trap_flag.datamisalign)
    );
    
    // Branch Unit
    branch_unit branch_unit (
        .start                              (start),
        .clk                                (clk),
        .cflow_mode_reg                     (control_signal_e.cflow_mode),
        .branch_mode_reg                    (control_signal_e.funct3.branch_mode),
        .in_a_reg                           (fwd_a),
        .in_b_reg                           (fwd_b),
        .pred_taken_reg                     (pred_taken_e),
        .pc_pred_reg                        (pc_pred_e),
        .aluresult_reg                      (aluresult_e),
        .pc_jump                            (pc_jump),
        .cflow_valid                        (cflow_valid),
        .cflow_taken                        (cflow_taken),
        .mispredict                         (mispredict)
    );

    // Hazard Packet
    always_comb begin
        hazard_bus.req.mispredict           = mispredict;
        hazard_bus.req.rs1_e                = rs1_e;
        hazard_bus.req.rs2_e                = rs2_e;
        hazard_bus.req.rd_e                 = rd_e;
        hazard_bus.req.memaccess_e          = control_signal_e.memaccess;
    end
    
    // Trap Packet
    always_comb begin
        trap_flag.instillegal               = 0;
        trap_flag.instmisalign              = 0;
        trap_flag.imemfault                 = 0;
        trap_flag.dmemfault                 = 0;
        
        if (trap_req_prev.valid) begin
            trap_req_e                      = trap_req_prev;
        end
        else begin 
            unique case (control_signal_e.sysop_mode)
                SYSOP_ECALL: begin
                    trap_req_e.valid        = 1;
                    trap_req_e.mode         = TRAP_ENTER;
                    trap_req_e.cause        = CAUSE_ECALL_MMODE;
                    trap_req_e.pc           = pc_e;
                    trap_req_e.tval         = 32'b0;
                end
                SYSOP_EBREAK: begin
                    trap_req_e.valid        = 1;
                    trap_req_e.mode         = TRAP_ENTER;
                    trap_req_e.cause        = CAUSE_BREAKPOINT;
                    trap_req_e.pc           = pc_e;
                    trap_req_e.tval         = 32'b0;
                end
                SYSOP_MRET: begin
                    trap_req_e.valid        = 1;
                    trap_req_e.mode         = TRAP_RETURN;
                    trap_req_e.cause        = CAUSE_INST_MISALIGNED;    // Default
                    trap_req_e.pc           = pc_e;
                    trap_req_e.tval         = 32'b0;
                end
                default: begin
                    if (trap_flag.datamisalign) begin
                        trap_req_e.valid    = 1;
                        trap_req_e.mode     = TRAP_ENTER;
                        trap_req_e.cause    = (control_signal_e.memaccess == MEM_WRITE) ? CAUSE_STORE_ADDR_MISALIGN : CAUSE_LOAD_ADDR_MISALIGN;
                        trap_req_e.pc       = pc_e;
                        trap_req_e.tval     = aluresult_e;
                    end
                    else trap_req_e         = '0;
                end
            endcase
        end
    end
    
    // CSR Packet
    always_comb begin
        csr_wdata_e = control_signal_e.csr_req.use_imm ? immext_e : fwd_a;
    end
endmodule