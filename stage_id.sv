timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_id (
    input   logic                   start, clk,

    input   logic [31:0]            pc_f,
    input   logic [31:0]            pcplus4_f,
    input   inst_t                  inst_f,

    input   logic [31:0]            result_e, result_m, result_w,
    
    input   control_signal_t        control_signal_w,
    input   logic                   kill_w,
    input   logic [4:0]             rd_w,

    output  control_signal_t        control_signal_d,
    output  logic [31:0]            pc_d,
    output  logic [31:0]            pcplus4_d,
    output  inst_t                  inst_d,
    output  logic [4:0]             rs1_d, rs2_d, rd_d,
    output  logic [31:0]            rdata1_d, rdata2_d,
    output  logic [31:0]            immext_d,
    
    output  pcsrc_t                 pcsrc,
    output  logic [31:0]            pc_jump, 

    input   trap_res_t              trap_res,
    input   trap_req_t              trap_req_f,
    output  trap_req_t              trap_req_d,
    hazard_interface.requester      hazard_bus
);

    trap_flag_t                     trap_flag;
    trap_req_t                      trap_req_prev;

    always_ff@(posedge clk) begin
        if (!start) begin
            trap_req_prev           <= '0;
            pc_d                    <= 32'b0;
            pcplus4_d               <= 32'b0;
        end
        else begin
            priority if (hazard_bus.res.flush_d) begin
                trap_req_prev       <= '0;
                pc_d                <= 32'b0;
                pcplus4_d           <= 32'b0;          
            end
            else if (hazard_bus.res.stall_d) begin
                trap_req_prev       <= trap_req_prev;
                pc_d                <= pc_d;
                pcplus4_d           <= pcplus4_d;   
            end
            else begin
                trap_req_prev       <= trap_req_f;
                pc_d                <= pc_f;
                pcplus4_d           <= pcplus4_f;
            end
        end
    end
    
    always_comb begin
        inst_d = inst_f;
    end
    
    (* DONT_TOUCH = "true" *)
    control_unit control_unit (    
        .inst                       (inst_d),
        .nextpc_mode                (control_signal_d.nextpc_mode),
        .cflow_mode                 (control_signal_d.cflow_mode),
        .funct3                     (control_signal_d.funct3),
        .csr_req                    (control_signal_d.csr_req),
        .fencei                     (control_signal_d.fencei),
        .immsrc                     (control_signal_d.immsrc),
        .alusrc_a                   (control_signal_d.alusrc_a),
        .alusrc_b                   (control_signal_d.alusrc_b),
        .alucontrol                 (control_signal_d.alucontrol),
        .memaccess                  (control_signal_d.memaccess),
        .resultsrc                  (control_signal_d.resultsrc),
        .regwrite                   (control_signal_d.regwrite),
        .instillegal                (trap_flag.instillegal)
    );
    
    // Register File
    always_comb begin
        rs1_d = inst_d.r.rs1;
        rs2_d = inst_d.r.rs2;
        rd_d  = inst_d.r.rd;
    end
    
    (* DONT_TOUCH = "true" *)
    regfile regfile (
        .clk                        (clk),
        .regwrite                   (control_signal_w.regwrite && !kill_w),
        .waddr                      (rd_w),
        .wdata                      (result_w),
        .raddr1                     (rs1_d),
        .raddr2                     (rs2_d),
        .rdata1                     (rdata1_d),
        .rdata2                     (rdata2_d)
    );

    // Immediate Extender
    (* DONT_TOUCH = "true" *)
    imm_extender imm_extender (
        .inst                       (inst_d),
        .immsrc                     (control_signal_d.immsrc),
        .immext                     (immext_d)
    );
    
    // Branch Forwarder
    logic [31:0] fwd_a, fwd_b;
    
    always_comb begin
        unique case(hazard_bus.res.forwarda_d)
            FWD_ID:                 fwd_a = rdata1_d;
            FWD_EX:                 fwd_a = result_e;
            FWD_MEM:                fwd_a = result_m;
            FWD_WB:                 fwd_a = result_w;
            default:                fwd_a = rdata1_d;
        endcase

        unique case(hazard_bus.res.forwardb_d)
            FWD_ID:                 fwd_b = rdata2_d;
            FWD_EX:                 fwd_b = result_e;
            FWD_MEM:                fwd_b = result_m;
            FWD_WB:                 fwd_b = result_w;
            default:                fwd_b = rdata2_d;
        endcase
    end
    
    // Branch Unit
    (* DONT_TOUCH = "true" *)
    branch_unit branch_unit (
        .nextpc_mode                (control_signal_d.nextpc_mode),
        .branch_mode                (control_signal_d.funct3),
        .in_a                       (fwd_a),
        .in_b                       (fwd_b),
        .redirflag                  (trap_res.redirflag),
        .pcsrc                      (pcsrc)
    );
    
    // PCJump Generator
    always_comb begin
        if (control_signal_d.nextpc_mode == NEXTPC_JALR) begin
            pc_jump = (immext_d + fwd_a) & ~32'd1;
        end
        else begin
            pc_jump = immext_d + pc_d;
        end
    end
    
    // Hazard Packet
    always_comb begin
        hazard_bus.req.nextpc_mode  = control_signal_d.nextpc_mode;
        hazard_bus.req.rs1_d        = rs1_d;
        hazard_bus.req.rs2_d        = rs2_d;
    end
    
    // Trap Packet
    always_comb begin
        if (trap_req_prev.valid) begin
            trap_req_d              = trap_req_prev;
        end
        else begin
            if (trap_flag.instillegal) begin
                trap_req_d.valid    = 1;
                trap_req_d.mode     = TRAP_ENTER;
                trap_req_d.cause    = CAUSE_ILLEGAL_INSTRUCTION;
                trap_req_d.pc       = pc_d;
                trap_req_d.tval     = inst_d;
            end
            else trap_req_d         = '0;
        end
    end

endmodule