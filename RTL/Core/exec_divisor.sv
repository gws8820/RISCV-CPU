timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module exec_divisor (
    input   logic           start, clk,
    input   logic           flush,
    input   logic           ex_fire,
    input   aluop_t         aluop,
    input   alucontrol_t    alucontrol,
    input   logic [31:0]    in_a, in_b,
    output  logic           div_valid,
    output  logic [31:0]    divresult
);
    
    logic                   div_busy;

    logic [63:0]            shift_reg;
    logic [31:0]            shifted_high, shifted_low;
    logic [31:0]            divisor;
    
    logic [5:0]             shift_counter;
    
    logic                   is_signed;
    logic                   div_sign, rem_sign;
    logic [31:0]            abs_a, abs_b;
    
    always_comb begin
        {shifted_high, shifted_low} = shift_reg << 1;
    end
    
    always_comb begin
        unique case (alucontrol)
            ALU_DIV, ALU_REM: begin
                is_signed = 1;
            end
            default: begin
                is_signed = 0;
            end
        endcase
    end
    
    always_comb begin
        abs_a = (in_a[31] == 1) ? -in_a : in_a;
        abs_b = (in_b[31] == 1) ? -in_b : in_b;
    end
    
    always_ff@(posedge clk) begin
        if (!start) begin
            div_valid               <= 0;
            div_busy                <= 0;
            
            shift_reg               <= 64'd0;
            divisor                 <= 32'd0;
            
            shift_counter           <= 6'd0;
            
            div_sign                <= 0;
            rem_sign                <= 0;
        end
        else begin
            priority if (flush) begin
                div_valid           <= 0;
                div_busy            <= 0;
                shift_reg           <= 64'd0;
                divisor             <= 32'd0;
                shift_counter       <= 6'd0;
                div_sign            <= 0;
                rem_sign            <= 0;
            end
            else if (ex_fire && (aluop == ALUOP_DIV)) begin
                div_valid           <= 0;
                div_busy            <= 1;
                shift_counter       <= 6'd0;
                
                if (is_signed) begin
                    shift_reg       <= {32'b0,  abs_a};
                    divisor         <= abs_b;
                    
                    div_sign        <= in_a[31] ^ in_b[31];
                    rem_sign        <= in_a[31];
                end
                else begin
                    shift_reg       <= {32'b0,  in_a};
                    divisor         <= in_b;
                end
            end
            else if (div_busy) begin
                if (shift_counter == (SHIFT_COUNT - 1)) begin
                    div_valid       <= 1;
                    div_busy        <= 0;
                    shift_counter   <= 6'd0;
                end
                else begin
                    div_valid       <= 0;
                    shift_counter   <= shift_counter + 1;
                end

                if (shifted_high >= divisor) begin
                    shift_reg   <= {(shifted_high - divisor), shifted_low} + 1;
                end
                else begin
                    shift_reg   <= {shifted_high, shifted_low};
                end
            end
            else begin
                div_valid           <= 0;
            end
        end
    end

    always_comb begin
        unique case (alucontrol)
            ALU_DIV:    divresult = div_sign ? -shift_reg[31:0] : shift_reg[31:0];
            ALU_DIVU:   divresult = shift_reg[31:0];
            ALU_REM:    divresult = rem_sign ? -shift_reg[63:32] : shift_reg[63:32];
            ALU_REMU:   divresult = shift_reg[63:32];
            default:    divresult = 32'd0;
        endcase
    end

endmodule