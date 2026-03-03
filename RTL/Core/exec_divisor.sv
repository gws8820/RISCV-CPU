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

    struct packed {
        logic               valid;
        logic [31:0]        data;
    } div_exception;

    logic [63:0]            shift_reg;
    logic [63:0]            iter1_out, iter2_out;
    logic [31:0]            iter1_high, iter1_low;
    logic [31:0]            iter2_high, iter2_low;
    logic [31:0]            divisor;

    logic [5:0]             shift_counter;

    logic                   is_signed;
    logic                   div_sign, rem_sign;
    logic [31:0]            abs_a, abs_b;

    always_comb begin
        {iter1_high, iter1_low} = shift_reg << 1;
        iter1_out = (iter1_high >= divisor) ? {iter1_high - divisor, iter1_low} + 1
                                            : {iter1_high, iter1_low};

        {iter2_high, iter2_low} = iter1_out << 1;
        iter2_out = (iter2_high >= divisor) ? {iter2_high - divisor, iter2_low} + 1
                                            : {iter2_high, iter2_low};
    end

    always_comb begin
        unique case (alucontrol)
            ALU_DIV, ALU_REM: is_signed = 1;
            default:          is_signed = 0;
        endcase
    end

    always_comb begin
        abs_a = in_a[31] ? -in_a : in_a;
        abs_b = in_b[31] ? -in_b : in_b;
    end

    logic is_div_zero, is_signed_overflow;
    always_comb begin
        is_div_zero        = (in_b == 32'd0);
        is_signed_overflow = is_signed && (in_a == 32'h8000_0000) && (in_b == 32'hFFFF_FFFF);
    end

    always_ff@(posedge clk) begin
        if (!start) begin
            div_valid     <= 0;
            div_busy      <= 0;
        end
        else begin
            priority if (flush) begin
                div_valid           <= 0;
                div_busy            <= 0;
            end
            else if (ex_fire && (aluop == ALUOP_DIV)) begin
                div_valid     <= 0;
                div_busy      <= 1;
                shift_counter <= 6'd0;

                if (is_div_zero) begin
                    div_exception.valid <= 1;

                    unique case (alucontrol)
                        ALU_DIV, ALU_DIVU: div_exception.data <= 32'hFFFF_FFFF;
                        ALU_REM, ALU_REMU: div_exception.data <= in_a;
                        default:           div_exception.data <= 32'd0;
                    endcase

                    if (is_signed) begin
                        shift_reg <= {32'b0, abs_a};
                        divisor   <= abs_b;
                        div_sign  <= in_a[31] ^ in_b[31];
                        rem_sign  <= in_a[31];
                    end else begin
                        shift_reg <= {32'b0, in_a};
                        divisor   <= in_b;
                    end
                end
                else if (is_signed_overflow) begin
                    div_exception.valid <= 1;

                    unique case (alucontrol)
                        ALU_DIV: div_exception.data <= 32'h8000_0000;
                        ALU_REM: div_exception.data <= 32'd0;
                        default: div_exception.data <= 32'd0;
                    endcase

                    shift_reg <= {32'b0, abs_a};
                    divisor   <= abs_b;
                    div_sign  <= in_a[31] ^ in_b[31];
                    rem_sign  <= in_a[31];
                end
                else begin
                    div_exception.valid <= 0;

                    if (is_signed) begin
                        shift_reg <= {32'b0, abs_a};
                        divisor   <= abs_b;
                        div_sign  <= in_a[31] ^ in_b[31];
                        rem_sign  <= in_a[31];
                    end else begin
                        shift_reg <= {32'b0, in_a};
                        divisor   <= in_b;
                    end
                end
            end
            else if (div_busy) begin
                if (shift_counter == (SHIFT_COUNT - 1)) begin
                    div_valid     <= 1;
                    div_busy      <= 0;
                    shift_counter <= 6'd0;
                end
                else begin
                    div_valid     <= 0;
                    shift_counter <= shift_counter + 1;
                end

                shift_reg <= iter2_out;
            end
            else begin
                div_valid <= 0;
            end
        end
    end

    always_comb begin
        if (div_exception.valid) begin
            divresult                 = div_exception.data;
        end 
        else begin
            unique case (alucontrol)
                ALU_DIV:    divresult = div_sign ? -shift_reg[31:0]  : shift_reg[31:0];
                ALU_DIVU:   divresult = shift_reg[31:0];
                ALU_REM:    divresult = rem_sign ? -shift_reg[63:32] : shift_reg[63:32];
                ALU_REMU:   divresult = shift_reg[63:32];
                default:    divresult = 32'd0;
            endcase
        end
    end

endmodule
