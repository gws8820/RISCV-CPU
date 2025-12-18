timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

function automatic logic check_csr_write(input csr_mode_t mode, input logic [4:0] wtarget);
    unique case (mode)
        CSR_RW, CSR_RWI:                    return 1'b1;
        CSR_RS, CSR_RC, CSR_RSI, CSR_RCI:   return (wtarget != 5'd0);
        default:                            return 1'b0;
    endcase
endfunction

module control_csr_decoder (
    input   opcode_t        opcode,
    input   logic [4:0]     wtarget,
    input   csr_mode_t      csr_mode,
    input   logic [11:0]    csr_target,
    output  csr_req_t       csr_req,
    output  logic           illegal_csr
);

    logic csr_write;
    assign csr_write = check_csr_write(csr_mode, wtarget);

    always_comb begin
        if (opcode == OP_SYSTEM && csr_mode != CSR_NOP) begin
            unique case (csr_target)
                CSR_ADDR_MSTATUS,
                CSR_ADDR_MIE,
                CSR_ADDR_MTVEC,
                CSR_ADDR_MSCRATCH,
                CSR_ADDR_MEPC,
                CSR_ADDR_MCAUSE,
                CSR_ADDR_MTVAL,
                CSR_ADDR_MIP: begin
                    illegal_csr             = 0;
                    csr_req.valid           = 1;
                    csr_req.use_imm         = csr_mode[2];
                    csr_req.csr_mode        = csr_mode;
                    csr_req.csr_target      = csr_target;
                end
                CSR_ADDR_MHARTID: begin
                    if (csr_write) begin
                        illegal_csr         = 1;
                        csr_req             = '0;
                    end
                    else begin
                        illegal_csr         = 0;
                        csr_req.valid       = 1;
                        csr_req.use_imm     = csr_mode[2];
                        csr_req.csr_mode    = csr_mode;
                        csr_req.csr_target  = csr_target;
                    end
                end
                default: begin
                    illegal_csr             = 1;
                    csr_req                 = '0;
                end
            endcase
        end
        else begin
            illegal_csr                     = 0;
            csr_req                         = '0;
        end
    end

endmodule