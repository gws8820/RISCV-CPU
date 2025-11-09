timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module csr_unit (
    input   logic           start, clk,
    input   csr_pkt_t       csr_pkt,
    input   logic [31:0]    csr_wdata,
    input   trap_pkt_t      trap_pkt,
    output  logic [31:0]    csr_result,
    output  logic [31:0]    mtvec_o, mepc_o
);

    csr_t csr;
    logic [31:0] wmask, wdata, eff_data;
    
    always_comb begin
        mtvec_o = csr.mtvec;
        mepc_o  = csr.mepc;
    end
    
    always_comb begin
        if (csr_pkt.valid) begin
            unique case(csr_pkt.csr_target)
                CSR_ADDR_MSTATUS:   begin
                    csr_result = csr.mstatus;
                    wmask      = CSR_MASK_MSTATUS;
                end
                CSR_ADDR_MTVEC:     begin
                    csr_result = csr.mtvec;
                    wmask      = CSR_MASK_MTVEC;
                end
                CSR_ADDR_MIE:       begin
                    csr_result = csr.mie;
                    wmask      = CSR_MASK_MIE;
                end
                CSR_ADDR_MIP:       begin
                    csr_result = csr.mip;
                    wmask      = CSR_MASK_MIP;
                end
                CSR_ADDR_MEPC:      begin
                    csr_result = csr.mepc;
                    wmask      = CSR_MASK_MEPC;
                end
                CSR_ADDR_MCAUSE:    begin
                    csr_result = csr.mcause;
                    wmask      = CSR_MASK_MCAUSE;
                end
                CSR_ADDR_MTVAL:     begin
                    csr_result = csr.mtval;
                    wmask      = CSR_MASK_MTVAL;
                end
                CSR_ADDR_MHARTID:   begin
                    csr_result = csr.mhartid;
                    wmask      = CSR_MASK_MHARTID;
                end
                CSR_ADDR_MSCRATCH:  begin
                    csr_result = csr.mscratch;
                    wmask      = CSR_MASK_MSCRATCH;
                end
                default:            begin
                    csr_result = 32'b0;
                    wmask      = 32'b0;
                end
            endcase
            
            unique case (csr_pkt.csr_mode)
                CSR_RW,
                CSR_RWI:    wdata = csr_wdata;
                CSR_RS,
                CSR_RSI:    wdata = csr_result | csr_wdata; // Set bits
                CSR_RC,
                CSR_RCI:    wdata = csr_result & ~csr_wdata; // Clear bits
                default:    wdata = csr_result;
            endcase
            
            eff_data = (csr_result & ~wmask) | (wdata & wmask);
         end
         else begin
            csr_result  = 32'b0;
            wmask       = 32'b0;
            wdata       = 32'b0;
            eff_data    = 32'b0;
         end
    end
    
    always_ff@(posedge clk) begin
        if (!start) begin
            csr.mstatus  <= CSR_VALUE_MSTATUS;
            csr.mtvec    <= CSR_VALUE_MTVEC;
            csr.mie      <= 32'b0;
            csr.mip      <= 32'b0;
            csr.mepc     <= 32'b0;
            csr.mcause   <= 32'b0;
            csr.mtval    <= 32'b0;
            csr.mhartid  <= CSR_VALUE_MHARTID;
            csr.mscratch <= 32'b0;
        end
        
        else begin
            if (trap_pkt.mode != TRAP_NONE) begin // Trap Handling
                unique case (trap_pkt.mode)
                    TRAP_ENTER: begin
                        csr.mstatus[MPIE_BIT] <= csr.mstatus[MIE_BIT];    // Push
                        csr.mstatus[MIE_BIT] <= 0;
                        
                        csr.mcause  <= {1'b0, trap_pkt.cause[30:0]};   // Interrupt
                        csr.mepc    <= {trap_pkt.pc[31:2], 2'b00};     // PC Alignment
                        csr.mtval   <= trap_pkt.tval;
                    end
                    TRAP_RETURN: begin
                        csr.mstatus[MIE_BIT] <= csr.mstatus[MPIE_BIT];    // Pop
                        csr.mstatus[MPIE_BIT] <= 1;
                    end
                    default: ;
                endcase
            end
            
            else if (csr_pkt.valid) begin // CSR
                unique case (csr_pkt.csr_target)
                    CSR_ADDR_MSTATUS:   csr.mstatus  <= eff_data;
                    CSR_ADDR_MTVEC:     csr.mtvec    <= eff_data;
                    CSR_ADDR_MIE:       csr.mie      <= eff_data;
                    CSR_ADDR_MIP:       csr.mip      <= eff_data;
                    CSR_ADDR_MEPC:      csr.mepc     <= eff_data;
                    CSR_ADDR_MCAUSE:    csr.mcause   <= eff_data;
                    CSR_ADDR_MTVAL:     csr.mtval    <= eff_data;
                    CSR_ADDR_MHARTID:   csr.mhartid  <= eff_data;
                    CSR_ADDR_MSCRATCH:  csr.mscratch <= eff_data;
                    default: ;
                endcase
            end
        end
    end

endmodule