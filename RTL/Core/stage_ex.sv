timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_ex (
    input   logic                           start, clk,

    input   control_bus_t                   control_bus_d,
    input   cflow_hint_t                    cflow_hint_d,
    input   logic [31:0]                    pc_d,
    input   logic [31:0]                    pcplus4_d,
    input   logic [31:0]                    pc_pred_d,
    input   logic                           pred_taken_d,
    input   logic [4:0]                     rs1_d, rs2_d, rd_d,
    input   logic [31:0]                    rdata1_d, rdata2_d,
    input   logic [31:0]                    immext_d,

    input   logic [31:0]                    result_m1, result_m2, result_w,

    output  control_bus_t                   control_bus_e,
    output  logic [31:0]                    pc_e,
    output  logic [31:0]                    pcplus4_e,
    output  logic [4:0]                     rs1_e, rs2_e, rd_e,

    output  logic                           alu_valid, mul_valid, div_valid,
    output  logic [31:0]                    aluresult_e, mulresult_e, divresult_e,
    
    output  logic [31:0]                    storedata_e,
    output  logic [31:0]                    csr_wdata_e,
    
    output  logic [31:0]                    pc_jump,
    output  cflow_mode_t                    cflow_mode_reg,
    output  cflow_hint_t                    cflow_hint_reg,
    output  logic                           cflow_taken,
    output  logic                           mispredict,
    output  logic                           ex_fire,

    input   trap_req_t                      trap_req_d,
    output  trap_req_t                      trap_req_e,
    input   hazard_res_t                    hazard_res
);

    trap_req_t                              trap_req_prev;

    cflow_hint_t                            cflow_hint_e;
    logic [31:0]                            pc_pred_e;
    logic                                   pred_taken_e;
    logic [31:0]                            immext_e;
    logic [31:0]                            rdata1_e, rdata2_e;
    
    logic [31:0]                            in_a, in_b;

    always_ff@(posedge clk) begin
        if (!start) begin
            ex_fire                         <= 0;
            control_bus_e                   <= '0;
            trap_req_prev                   <= '0;
        end
        else begin
            priority if (hazard_res.flush_e) begin
                ex_fire                     <= 0;
                control_bus_e               <= '0;
                trap_req_prev               <= '0;
            end
            else if (hazard_res.stall_e) begin
                ex_fire                     <= 0;
            end
            else begin
                ex_fire                     <= 1;
                control_bus_e               <= control_bus_d;
                cflow_hint_e                <= cflow_hint_d;
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
    logic [31:0]                            fwd_a, fwd_b;
    assign storedata_e = fwd_b;
    
    always_comb begin
        unique case(hazard_res.forwarda_e)
            FWD_EX:                         fwd_a = rdata1_e;
            FWD_MEM1:                       fwd_a = result_m1;
            FWD_MEM2:                       fwd_a = result_m2;
            FWD_WB:                         fwd_a = result_w;
            default:                        fwd_a = rdata1_e;
        endcase

        unique case(hazard_res.forwardb_e)
            FWD_EX:                         fwd_b = rdata2_e;
            FWD_MEM1:                       fwd_b = result_m1;
            FWD_MEM2:                       fwd_b = result_m2;
            FWD_WB:                         fwd_b = result_w;
            default:                        fwd_b = rdata2_e;
        endcase
    end
    
    // ALU Source Selector
    always_comb begin
        unique case(control_bus_e.alusrc_a)
            SRCA_REG:                       in_a = fwd_a;
            SRCA_PC:                        in_a = pc_e;
            SRCA_ZERO:                      in_a = 32'b0;
            default:                        in_a = fwd_a;
        endcase

        unique case(control_bus_e.alusrc_b)
            SRCB_REG:                       in_b = fwd_b;
            SRCB_IMM:                       in_b = immext_e;
            default:                        in_b = fwd_b;
        endcase
    end

    // ALU
    exec_alu alu (
        .in_a                               (in_a),
        .in_b                               (in_b),
        .alucontrol                         (control_bus_e.alucontrol),
        .alu_valid                          (alu_valid),
        .aluresult                          (aluresult_e)
    );

    // Multiplier
    exec_multiplier multiplier (
        .start                              (start),
        .clk                                (clk),
        .flush                              (hazard_res.flush_e_sidefx),
        .ex_fire                            (ex_fire),
        .aluop                              (control_bus_e.aluop),
        .alucontrol                         (control_bus_e.alucontrol),
        .in_a                               (in_a),
        .in_b                               (in_b),
        .mul_valid                          (mul_valid),
        .mulresult                          (mulresult_e)
    );

    // Divisor
    exec_divisor divisor (
        .start                              (start),
        .clk                                (clk),
        .flush                              (hazard_res.flush_e_sidefx),
        .ex_fire                            (ex_fire),
        .aluop                              (control_bus_e.aluop),
        .alucontrol                         (control_bus_e.alucontrol),
        .in_a                               (in_a),
        .in_b                               (in_b),
        .div_valid                          (div_valid),
        .divresult                          (divresult_e)
    );
    
    // Branch Unit
    branch_unit branch_unit (
        .start                              (start),
        .clk                                (clk),
        .flush                              (hazard_res.flush_e_sidefx),
        .ex_fire                            (ex_fire),
        .cflow_mode                         (control_bus_e.cflow_mode),
        .branch_mode                        (control_bus_e.funct3.branch_mode),
        .cflow_hint                         (cflow_hint_e),
        .in_a                               (fwd_a), // Prevent ALU operands from being remapped to PC/imm/zero.
        .in_b                               (fwd_b),
        .pred_taken                         (pred_taken_e),
        .pc_pred                            (pc_pred_e),
        .aluresult                          (aluresult_e),
        .pc_jump                            (pc_jump),
        .cflow_mode_reg                     (cflow_mode_reg),
        .cflow_hint_reg                     (cflow_hint_reg),
        .cflow_taken                        (cflow_taken),
        .mispredict                         (mispredict)
    );

    // Trap Packet
    always_comb begin
        if (trap_req_prev.valid) begin
            trap_req_e                      = trap_req_prev;
        end
        else begin 
            unique case (control_bus_e.sysop_mode)
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
                    trap_req_e              = '0;
                end
            endcase
        end
    end
    
    // CSR Packet
    always_comb begin
        csr_wdata_e = control_bus_e.csr_req.use_imm ? immext_e : fwd_a;
    end
endmodule