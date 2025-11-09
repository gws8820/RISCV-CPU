timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module pipelined_rv32i_cpu(
    input logic rstn, clk
);
    
    logic start;
    always_ff @(posedge clk) begin
        start           <= rstn;
    end
    
    trap_req_t trap_req;
    trap_res_t trap_res;
    
    hazard_req_t    hazard_req;
    hazard_res_t    hazard_res;
    
    (* DONT_TOUCH = "true" *)
    hazard_unit hazard_unit (
        .start      (start),
        .hazard_req (hazard_req),
        .hazard_res (hazard_res)
    );
    
    //--------------IF-----------------

    // IF Register
    logic [31:0] pc_f;
        
    // Program Counter
    pcsrc_t pcsrc;
    logic [31:0] pc_next;
    logic [31:0] pc_imm;
    logic [31:0] pc_alu;
    
    always_comb begin
        unique case(pcsrc)
            PC_REDIR:   pc_next = trap_res.rediraddr;
            PC_PLUS4:   pc_next = pc_f + 4;
            PC_PLUSIMM: pc_next = pc_imm;
            PC_ALU:     pc_next = pc_alu;
            default:    pc_next = pc_f + 4;
        endcase
    end

    (* DONT_TOUCH = "true" *)
    program_counter program_counter (
        .start   (start), // Starts PC from Zero
        .clk     (clk),
        .stall_f (hazard_res.stall_f),
        .pc_next (pc_next),
        .pc      (pc_f)
    );
    
    // Inst Misalign Checker
    (* DONT_TOUCH = "true" *)
    inst_misalign_checker inst_misalign_checker (
        .pc          (pc_f),
        .instmisalign(trap_req.instmisalign)
    );

    // Instruction Memory
    inst_t inst_f;
    
    (* DONT_TOUCH = "true" *)
    instruction_memory instruction_memory (
        .start       (start),
        .clk         (clk),
        .pc          (pc_f),
        .instmisalign(trap_req.instmisalign),
        .flush_d     (hazard_res.flush_d),
        .stall_d     (hazard_res.stall_d),
        .imemfault   (trap_req.imemfault),
        .inst        (inst_f)
    );
    
    logic [31:0] pcplus4_f;
    assign pcplus4_f = pc_f + 4;
    
    // Hazard Packet
    always_comb begin
        hazard_req.pcsrc = pcsrc;
    end
    
    // Trap Packet
    trap_pkt_t trap_pkt_f;
    
    always_comb begin
        if (!start) begin
            trap_pkt_f = '0;
        end
        else begin
            if (trap_req.instmisalign) begin
                trap_pkt_f.valid  = 1;
                trap_pkt_f.mode   = TRAP_ENTER;
                trap_pkt_f.cause  = CAUSE_INST_MISALIGNED;
                trap_pkt_f.pc     = pc_f;
                trap_pkt_f.tval   = pc_f;
            end
            else if (trap_req.imemfault) begin
                trap_pkt_f.valid  = 1;
                trap_pkt_f.mode   = TRAP_ENTER;
                trap_pkt_f.cause  = CAUSE_INST_ACCESS_FAULT;
                trap_pkt_f.pc     = pc_f;
                trap_pkt_f.tval   = pc_f;
            end
            else trap_pkt_f       = '0;
        end
    end

    //--------------ID-----------------
    
    // ID Register
    control_signal_t    control_signal_d;
    trap_pkt_t          trap_pkt_d_reg, trap_pkt_d;
    inst_t              inst_d;
    logic [31:0]        pc_d, pcplus4_d;

    always_ff@(posedge clk) begin
        if (!start) begin
            trap_pkt_d_reg      <= '0;
            pc_d                <= 32'b0;
            pcplus4_d           <= 32'b0;
        end
        else begin
            priority if (hazard_res.flush_d) begin
                trap_pkt_d_reg  <= '0;
                pc_d            <= 32'b0;
                pcplus4_d       <= 32'b0;          
            end
            else if (hazard_res.stall_d) begin
                trap_pkt_d_reg  <= trap_pkt_d_reg;
                pc_d            <= pc_d;
                pcplus4_d       <= pcplus4_d;   
            end
            else begin
                trap_pkt_d_reg  <= trap_pkt_f;
                pc_d            <= pc_f;
                pcplus4_d       <= pcplus4_f;
            end
        end
    end
    
    always_comb begin
        inst_d = inst_f;
    end
    
    // WB Register
    logic        kill_w;
    logic [4:0]  rd_w;
    logic [31:0] result_w;
    
    (* DONT_TOUCH = "true" *)
    control_unit control_unit (    
        .inst       (inst_d),
        .nextpc_mode(control_signal_d.nextpc_mode),
        .cflow_mode (control_signal_d.cflow_mode),
        .funct3     (control_signal_d.funct3),
        .csr_pkt    (control_signal_d.csr_pkt),
        .fencei     (control_signal_d.fencei),
        .immsrc     (control_signal_d.immsrc),
        .alusrc_a   (control_signal_d.alusrc_a),
        .alusrc_b   (control_signal_d.alusrc_b),
        .alucontrol (control_signal_d.alucontrol),
        .memaccess  (control_signal_d.memaccess),
        .resultsrc  (control_signal_d.resultsrc),
        .regwrite   (control_signal_d.regwrite),
        .instillegal(trap_req.instillegal)
    );
    
    // Register File
    logic [4:0] rs1_d, rs2_d, rd_d; 
    
    assign rs1_d = inst_d.r.rs1;
    assign rs2_d = inst_d.r.rs2;
    assign rd_d  = inst_d.r.rd;
    
    logic [31:0] rdata1_d, rdata2_d;
    
    (* DONT_TOUCH = "true" *)
    regfile regfile (
        .clk     (clk),
        .regwrite(control_signal_w.regwrite && !kill_w),
        .waddr   (rd_w),
        .wdata   (result_w),
        .raddr1  (rs1_d),
        .raddr2  (rs2_d),
        .rdata1  (rdata1_d),
        .rdata2  (rdata2_d)
    );

    // Immediate Extender
    logic [31:0] immext_d;

    (* DONT_TOUCH = "true" *)
    imm_extender imm_extender (
        .inst  (inst_d),
        .immsrc(control_signal_d.immsrc),
        .immext(immext_d)
    );
    
    // Hazard Packet
    always_comb begin
        hazard_req.rs1_d = rs1_d;
        hazard_req.rs2_d = rs2_d;
    end
    
    // Trap Packet
    always_comb begin
        if (trap_pkt_d_reg.valid) begin
            trap_pkt_d = trap_pkt_d_reg;
        end
        else begin 
            if (trap_req.instillegal) begin
                trap_pkt_d.valid  = 1;
                trap_pkt_d.mode   = TRAP_ENTER;
                trap_pkt_d.cause  = CAUSE_ILLEGAL_INSTRUCTION;
                trap_pkt_d.pc     = pc_d;
                trap_pkt_d.tval   = inst_d;
            end
            else trap_pkt_d       = '0;
        end
    end

    //--------------EX-----------------
    
    // EX Register
    control_signal_t    control_signal_e;
    trap_pkt_t          trap_pkt_e_reg, trap_pkt_e;
    logic [4:0]         rs1_e, rs2_e, rd_e;
    logic [31:0]        rdata1_e, rdata2_e;
    logic [31:0]        pc_e, pcplus4_e, immext_e;
    
    // MEM Register
    logic [31:0] result_m;
    
    always_ff@(posedge clk) begin
        if (!start) begin
            control_signal_e        <= '0;
            trap_pkt_e_reg          <= '0;
            rs1_e                   <= 5'b0;
            rs2_e                   <= 5'b0;
            rd_e                    <= 5'b0;
            rdata1_e                <= 32'b0;
            rdata2_e                <= 32'b0;
            pc_e                    <= 32'b0;
            pcplus4_e               <= 32'b0;
            immext_e                <= 32'b0;
        end
        else begin
            priority if (hazard_res.flush_e) begin
                control_signal_e    <= '0;
                trap_pkt_e_reg      <= '0;
                rs1_e               <= 5'b0;
                rs2_e               <= 5'b0;
                rd_e                <= 5'b0;
                rdata1_e            <= 32'b0;
                rdata2_e            <= 32'b0;
                pc_e                <= 32'b0;
                pcplus4_e           <= 32'b0;
                immext_e            <= 32'b0;
            end
            else begin
                control_signal_e    <= control_signal_d;
                trap_pkt_e_reg      <= trap_pkt_d;
                rs1_e               <= rs1_d;
                rs2_e               <= rs2_d;
                rd_e                <= rd_d;
                rdata1_e            <= rdata1_d;
                rdata2_e            <= rdata2_d;
                pc_e                <= pc_d;
                pcplus4_e           <= pcplus4_d;
                immext_e            <= immext_d;
            end
        end
    end

    // ALU Forwarder
    logic [31:0] fwd_a, fwd_b;
    
    always_comb begin
        unique case(hazard_res.forward_a)
            FWDA_EX:    fwd_a = rdata1_e;
            FWDA_MEM:   fwd_a = result_m;
            FWDA_WB:    fwd_a = result_w;
            default:    fwd_a = rdata1_e;
        endcase

        unique case(hazard_res.forward_b)
            FWDB_EX:    fwd_b = rdata2_e;
            FWDB_MEM:   fwd_b = result_m;
            FWDB_WB:    fwd_b = result_w;
            default:    fwd_b = rdata2_e;
        endcase
    end
    
    // ALU Source Selector
    logic [31:0] in_a, in_b;
    
    always_comb begin
        unique case(control_signal_e.alusrc_a)
            SRCA_REG:   in_a = fwd_a;
            SRCA_PC:    in_a = pc_e;
            SRCA_ZERO:  in_a = 32'b0;
            default:    in_a = fwd_a;
        endcase

        unique case(control_signal_e.alusrc_b)
            SRCB_REG:   in_b = fwd_b;
            SRCB_IMM:   in_b = immext_e;
            default:    in_b = fwd_b;
        endcase
    end

    // ALU
    logic [31:0] aluresult_e;
    
    (* DONT_TOUCH = "true" *)
    alu alu (
        .in_a      (in_a),
        .in_b      (in_b),
        .alucontrol(control_signal_e.alucontrol),
        .aluresult (aluresult_e)
    );
    
    // LSU Misalign Checker
    (* DONT_TOUCH = "true" *)
    lsu_misalign_checker lsu_misalign_checker (
        .aluresult   (aluresult_e),
        .memaccess   (control_signal_e.memaccess),
        .mask_mode   (control_signal_e.funct3),
        .datamisalign(trap_req.datamisalign)
    );

    always_comb begin
        pc_imm = pc_e + immext_e;
        pc_alu = aluresult_e & ~32'b1;
    end
    
    // Branch Unit
    (* DONT_TOUCH = "true" *)
    branch_unit branch_unit (
        .nextpc_mode(control_signal_e.nextpc_mode),
        .branch_mode(control_signal_e.funct3),
        .in_a       (in_a),
        .in_b       (in_b),
        .redirflag  (trap_res.redirflag),
        .pcsrc      (pcsrc)
    );
    
    // Hazard Packet
    always_comb begin
        hazard_req.rs1_e        = rs1_e;
        hazard_req.rs2_e        = rs2_e;
        hazard_req.rd_e         = rd_e;
        hazard_req.memaccess_e  = control_signal_e.memaccess;
    end
    
    // Trap Packet
    always_comb begin
        if (trap_pkt_e_reg.valid) begin
            trap_pkt_e = trap_pkt_e_reg;
        end
        else begin 
            unique case (control_signal_e.cflow_mode)
                CFLOW_ECALL: begin
                        trap_pkt_e.valid  = 1;
                        trap_pkt_e.mode   = TRAP_ENTER;
                        trap_pkt_e.cause  = CAUSE_ECALL_MMODE;
                        trap_pkt_e.pc     = pc_e;
                        trap_pkt_e.tval   = 32'b0;
                end
                CFLOW_EBREAK: begin
                        trap_pkt_e.valid  = 1;
                        trap_pkt_e.mode   = TRAP_ENTER;
                        trap_pkt_e.cause  = CAUSE_BREAKPOINT;
                        trap_pkt_e.pc     = pc_e;
                        trap_pkt_e.tval   = 32'b0;
                end
                CFLOW_MRET: begin
                        trap_pkt_e.valid  = 1;
                        trap_pkt_e.mode   = TRAP_RETURN;
                        trap_pkt_e.pc     = pc_e;
                        trap_pkt_e.tval   = 32'b0;
                end
                default: begin
                    if (trap_req.datamisalign) begin
                        trap_pkt_e.valid  = 1;
                        trap_pkt_e.mode   = TRAP_ENTER;
                        trap_pkt_e.cause  = (control_signal_e.memaccess == MEM_WRITE) ? CAUSE_STORE_ADDR_MISALIGN : CAUSE_LOAD_ADDR_MISALIGN;
                        trap_pkt_e.pc     = pc_e;
                        trap_pkt_e.tval   = aluresult_e;
                    end
                    else trap_pkt_e       = '0;
                end
            endcase
        end
    end
    
    // CSR Packet
    logic [31:0] csr_wdata_e;
    always_comb begin
        csr_wdata_e = control_signal_e.csr_pkt.use_imm ? immext_e : fwd_a;
    end

    //--------------MEM-----------------
    
    control_signal_t    control_signal_m;
    trap_pkt_t          trap_pkt_m_reg, trap_pkt_m;
    logic [31:0]        csr_wdata_m;
    logic [31:0]        aluresult_m;
    logic [31:0]        storedata_m;
    logic [4:0]         rs2_m, rd_m;
    logic [31:0]        pc_m;
    logic [31:0]        pcplus4_m;
    
    always_ff@(posedge clk) begin
        if (!start) begin
            control_signal_m    <= '0;
            trap_pkt_m_reg      <= '0;
            csr_wdata_m         <= 32'b0;
            aluresult_m         <= 32'b0;
            storedata_m         <= 32'b0;
            rs2_m               <= 32'b0;
            rd_m                <= 5'b0;
            pc_m                <= 32'b0;
            pcplus4_m           <= 32'b0;
        end
        else begin
            priority if (hazard_res.flush_m) begin
                control_signal_m    <= '0;
                trap_pkt_m_reg      <= '0;
                csr_wdata_m         <= 32'b0;
                aluresult_m         <= 32'b0;
                storedata_m         <= 32'b0;
                rs2_m               <= 32'b0;
                rd_m                <= 5'b0;
                pc_m                <= 32'b0;
                pcplus4_m           <= 32'b0;
            end
            else begin
                control_signal_m    <= control_signal_e;
                trap_pkt_m_reg      <= trap_pkt_e;
                csr_wdata_m         <= csr_wdata_e;
                aluresult_m         <= aluresult_e;
                storedata_m         <= rdata2_e;
                rs2_m               <= rs2_e;
                rd_m                <= rd_e;
                pc_m                <= pc_e;
                pcplus4_m           <= pcplus4_e;
            end
        end
    end

    // LSU Source Selector
    logic [31:0] store_data;
    always_comb begin
        unique case(hazard_res.forward_mem)
            0:        store_data = storedata_m;
            1:        store_data = result_w;
            default:  store_data = storedata_m;
        endcase
    end
    
    // Load Store Unit
    logic        kill_m;
    logic [31:0] memresult_m;
    
    (* DONT_TOUCH = "true" *)
    load_store_unit load_store_unit (
        .start    (start),
        .clk      (clk),
        .addr     (aluresult_m),
        .data     (store_data),
        .memaccess(kill_m ? MEM_DISABLED : control_signal_m.memaccess), // PREVENT MEMORY ACCESS IF TRAP OCCURRED
        .mask_mode(control_signal_m.funct3),
        .rdata_ext(memresult_m),
        .dmemfault(trap_req.dmemfault)
    );
    
    // Hazard Packet
    always_comb begin
        hazard_req.rs2_m        = rs2_m;
        hazard_req.rd_m         = rd_m;
        hazard_req.memaccess_m  = control_signal_m.memaccess;
        hazard_req.regwrite_m   = control_signal_m.regwrite;
        
        hazard_req.flushflag    = trap_res.flushflag || control_signal_m.fencei;
    end
    
    // Trap Packet
    always_comb begin
        kill_m = trap_pkt_m_reg.valid;
    
        if (trap_pkt_m_reg.valid) begin
            trap_pkt_m = trap_pkt_m_reg;
        end
        else begin 
            if (trap_req.dmemfault) begin
                trap_pkt_m.valid  = 1;
                trap_pkt_m.mode   = TRAP_ENTER;
                trap_pkt_m.cause  = (control_signal_m.memaccess == MEM_WRITE) ? CAUSE_STORE_ACCESS_FAULT : CAUSE_LOAD_ACCESS_FAULT;
                trap_pkt_m.pc     = pc_m;
                trap_pkt_m.tval   = aluresult_m;
            end
            else trap_pkt_m       = '0;
        end
    end

    // Trap Unit
    logic [31:0] mtvec, mepc;
    
    (* DONT_TOUCH = "true" *)
    trap_unit trap_unit (
        .trap_pkt(trap_pkt_m),
        .trap_res(trap_res),
        .mtvec_i (mtvec),
        .mepc_i  (mepc)
    );
    
    // CSR Unit
    logic [31:0] csrresult_m;
    
    (* DONT_TOUCH = "true" *)
    csr_unit csr_unit (
        .start          (start),
        .clk            (clk),
        .csr_pkt        (control_signal_m.csr_pkt),
        .csr_wdata      (csr_wdata_m),
        .trap_pkt       (trap_pkt_m),
        .csr_result     (csrresult_m),
        .mtvec_o        (mtvec),
        .mepc_o         (mepc)
    );
    
    // Pre-Result Selector
    always_comb begin
        unique case(control_signal_m.resultsrc)
            RESULT_ALU:     result_m = aluresult_m;
            RESULT_PCPLUS4: result_m = pcplus4_m;
            RESULT_CSR:     result_m = csrresult_m;
            default:        result_m = aluresult_m;
        endcase
    end
    
    //--------------WB-----------------
    
    control_signal_t    control_signal_w;
    trap_pkt_t          trap_pkt_w;
    logic [31:0]        result_w_reg;
    logic [31:0]        memresult_w;

    always_ff@(posedge clk) begin
        if (!start) begin
            control_signal_w    <= '0;
            trap_pkt_w          <= '0;
            result_w_reg        <= 32'b0;
            rd_w                <= 5'b0;
        end
        else begin
            control_signal_w    <= control_signal_m;
            trap_pkt_w          <= trap_pkt_m;
            result_w_reg        <= result_m;
            rd_w                <= rd_m;
        end
    end
    
    always_comb begin
        memresult_w = memresult_m;
    end
    
    // Result Selector
    always_comb begin
        unique case(control_signal_w.resultsrc)
            RESULT_MEM:     result_w = memresult_w;
            default:        result_w = result_w_reg;
        endcase
    end
    
    // Hazard Packet
    always_comb begin
        hazard_req.rd_w         = rd_w;
        hazard_req.regwrite_w   = control_signal_w.regwrite;
    end
    
    // Trap Packet
    always_comb begin
        kill_w                  = trap_pkt_w.valid;
    end
        
endmodule