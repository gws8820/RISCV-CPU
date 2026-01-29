timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module stage_id (
    input   logic                   start, clk,

    input   logic [31:0]            pc_f,
    input   logic [31:0]            pcplus4_f,
    input   logic [31:0]            pc_pred_f,
    input   logic                   pred_taken_f,
    input   inst_t                  inst_f,

    input   control_signal_t        control_signal_w,
    input   logic [4:0]             rd_w,
    input   logic [31:0]            result_w,

    output  control_signal_t        control_signal_d,
    output  cflow_hint_t            cflow_hint_d,
    output  logic [31:0]            pc_d,
    output  logic [31:0]            pcplus4_d,
    output  logic [31:0]            pc_pred_d,
    output  logic                   pred_taken_d,
    output  logic [4:0]             rs1_d, rs2_d, rd_d,
    output  logic [31:0]            rdata1_d, rdata2_d,
    output  logic [31:0]            immext_d,

    input   trap_req_t              trap_req_f,
    output  trap_req_t              trap_req_d,
    hazard_interface.requester      hazard_bus
);

    logic                           id_valid;
    inst_t                          inst_d;
    
    trap_flag_t                     trap_flag;
    trap_req_t                      trap_req_prev;

    always_ff@(posedge clk) begin
        if (!start) begin
            id_valid                <= 0;
            pc_d                    <= 32'b0;
            pcplus4_d               <= 32'b0;
            pc_pred_d               <= 32'b0;
            pred_taken_d            <= 0;

            trap_req_prev           <= '0;
        end
        else begin
            priority if (hazard_bus.res.flush_d) begin
                id_valid            <= 0;

                trap_req_prev       <= '0;
            end
            else if (hazard_bus.res.stall_d) begin
                id_valid            <= id_valid;
                pc_d                <= pc_d;
                pcplus4_d           <= pcplus4_d;
                pc_pred_d           <= pc_pred_d;
                pred_taken_d        <= pred_taken_d;

                trap_req_prev       <= trap_req_prev;
            end
            else begin
                id_valid            <= 1;
                pc_d                <= pc_f;
                pcplus4_d           <= pcplus4_f;
                pc_pred_d           <= pc_pred_f;
                pred_taken_d        <= pred_taken_f;
                
                trap_req_prev       <= trap_req_f;
            end
        end
    end
    
    always_comb begin
        unique if (hazard_bus.res.flush_d) begin
            inst_d = INST_NOP;
        end
        else begin
            inst_d = inst_f;
        end

        if (inst_d.i.opcode == OP_JAL) begin
            logic is_rd_link;
            is_rd_link  = (inst_d.j.rd == 5'd1) || (inst_d.j.rd == 5'd5);
            cflow_hint_d = is_rd_link ? CFHINT_CALL : CFHINT_NONE;
        end
        else if (inst_d.i.opcode == OP_JALR) begin
            logic is_rd_link;
            logic is_rs1_link;
            logic is_ret;

            is_rd_link  = (inst_d.i.rd  == 5'd1) || (inst_d.i.rd  == 5'd5);
            is_rs1_link = (inst_d.i.rs1 == 5'd1) || (inst_d.i.rs1 == 5'd5);
            is_ret      = (inst_d.i.rd == 5'd0) && is_rs1_link && (inst_d.i.imm == 12'd0);

            if (is_rd_link) begin
                cflow_hint_d = CFHINT_CALL;
            end
            else if (is_ret) begin
                cflow_hint_d = CFHINT_RET;
            end
            else begin
                cflow_hint_d = CFHINT_NONE;
            end
        end
        else begin
            cflow_hint_d = CFHINT_NONE;
        end
    end
    
    control_unit control_unit (    
        .inst                       (inst_d),
        .cflow_mode                 (control_signal_d.cflow_mode),
        .sysop_mode                 (control_signal_d.sysop_mode),
        .funct3                     (control_signal_d.funct3),
        .csr_req                    (control_signal_d.csr_req),
        .fencei                     (control_signal_d.fencei),
        .immsrc                     (control_signal_d.immsrc),
        .alusrc_a                   (control_signal_d.alusrc_a),
        .alusrc_b                   (control_signal_d.alusrc_b),
        .alucontrol                 (control_signal_d.alucontrol),
        .aluop                      (control_signal_d.aluop),
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
    
    regfile regfile (
        .clk                        (clk),
        .regwrite                   (control_signal_w.regwrite),
        .waddr                      (rd_w),
        .wdata                      (result_w),
        .raddr1                     (rs1_d),
        .raddr2                     (rs2_d),
        .rdata1                     (rdata1_d),
        .rdata2                     (rdata2_d)
    );

    // Immediate Extender
    imm_extender imm_extender (
        .inst                       (inst_d),
        .immsrc                     (control_signal_d.immsrc),
        .immext                     (immext_d)
    );
    
    // Hazard Packet
    always_comb begin
        hazard_bus.req.rs1_d        = rs1_d;
        hazard_bus.req.rs2_d        = rs2_d;
    end
    
    // Trap Packet
    always_comb begin
        trap_flag.instmisalign      = 0;
        trap_flag.imemfault         = 0;
        trap_flag.datamisalign      = 0;
        trap_flag.dmemfault         = 0;

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