timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;

module uart_tx_ctrl(
    input   logic               rstn,
    input   logic               clk,

    input   uart_res_t          res,
    input   logic               boot_en,
    input   logic               exit_en,
    input   logic  [7:0]        exit_code,
    input   logic               print_en,
    input   logic  [31:0]       print_data,

    input   logic               tx_ready,

    output  logic  [7:0]        tx_data,
    output  logic               tx_valid
);

    // ----------- Backward Signals -------------

    uart_tx_ctrl_t              tx_state;

    // --------- ACK/NAK (RES) Register ---------

    logic                       res_valid;
    uart_res_t                  res_reg;
    logic                       res_consume;

    assign res_consume = (tx_state == TX_CTRL_IDLE) && res_valid && tx_ready;

    always_ff @(posedge clk) begin
        if (!rstn) begin
            res_valid   <= 0;
            res_reg     <= RES_STBY;
        end
        else begin
            priority if (res == RES_ACK || res == RES_NAK) begin
                res_valid   <= 1;
                res_reg     <= res;
            end
            else if (res_consume) begin
                res_valid   <= 0;
            end
        end
    end

    // --------- TX FIFO (Ring Buffer) ---------

    // Struct arrays cannot be inferred as Distributed RAM by Vivado
    (* ram_style="distributed" *) logic [$bits(uart_tx_entry_t)-1:0] tx_fifo[0:CTRL_FIFO_SIZE-1];

    logic [CTRL_FIFO_BITS:0]    rd_ptr, wr_ptr; // MSB Indicates Wrap Bit
    logic                       fifo_empty, fifo_full;

    always_comb begin
        fifo_empty              = (rd_ptr == wr_ptr);
        fifo_full               = (wr_ptr[CTRL_FIFO_BITS]      != rd_ptr[CTRL_FIFO_BITS]) &&
                                  (wr_ptr[CTRL_FIFO_BITS-1:0]  == rd_ptr[CTRL_FIFO_BITS-1:0]);
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            wr_ptr  <= '0;
        end
        else if (!fifo_full) begin
            if (boot_en) begin
                tx_fifo[wr_ptr[CTRL_FIFO_BITS-1:0]]        <= {RES_BOOT, 3'd0, 8'd0};
                wr_ptr                                     <= wr_ptr + 1;
            end
            else if (exit_en) begin
                tx_fifo[wr_ptr[CTRL_FIFO_BITS-1:0]]        <= {RES_EXIT, 3'd1, exit_code};
                wr_ptr                                     <= wr_ptr + 1;
            end
            else if (print_en) begin
                tx_fifo[wr_ptr[CTRL_FIFO_BITS-1:0]]        <= {RES_PRINT, 3'd1, print_data[7:0]};
                wr_ptr                                     <= wr_ptr + 1;
            end
        end
    end

    // ------------- TX Controller -------------

    uart_tx_entry_t         active_entry;
    uart_tx_entry_t         res_entry;

    always_comb begin
        res_entry.res       = res_reg;
        res_entry.len       = 3'd0;
        res_entry.data      = 8'd0;
    end

    logic [7:0]             checksum;

    always_ff @(posedge clk) begin
        if (!rstn) begin
            rd_ptr          <= '0;

            tx_state        <= TX_CTRL_IDLE;
            tx_data         <= '0;
            tx_valid        <= 0;

            active_entry    <= '0;

            checksum        <= '0;
        end
        else begin
            unique case (tx_state)
                TX_CTRL_IDLE: begin
                    if (res_valid && tx_ready) begin
                        active_entry        <= res_entry;

                        tx_data             <= START_FLAG;
                        tx_valid            <= 1;
                        tx_state            <= TX_CTRL_RES;

                        checksum            <= START_FLAG;
                    end
                    else if (!fifo_empty && tx_ready) begin
                        active_entry        <= uart_tx_entry_t'(tx_fifo[rd_ptr[CTRL_FIFO_BITS-1:0]]);
                        rd_ptr              <= rd_ptr + 1;

                        tx_data             <= START_FLAG;
                        tx_valid            <= 1;
                        tx_state            <= TX_CTRL_RES;

                        checksum            <= START_FLAG;
                    end
                    else begin
                        tx_data             <= '0;
                        tx_valid            <= 0;
                        tx_state            <= TX_CTRL_IDLE;

                        checksum            <= '0;
                    end
                end

                TX_CTRL_RES: if (tx_ready) begin
                    tx_data                 <= active_entry.res;
                    tx_valid                <= 1;
                    tx_state                <= TX_CTRL_LEN;

                    checksum                <= checksum + active_entry.res;
                end

                TX_CTRL_LEN: if (tx_ready) begin
                    tx_data                 <= active_entry.len;
                    tx_valid                <= 1;
                    tx_state                <= (active_entry.len == 3'd0) ? TX_CTRL_CHECKSUM : TX_CTRL_PAYLOAD;

                    checksum                <= checksum + active_entry.len;
                end

                TX_CTRL_PAYLOAD: if (tx_ready) begin
                    tx_data                 <= active_entry.data;
                    tx_valid                <= 1;
                    tx_state                <= TX_CTRL_CHECKSUM;

                    checksum                <= checksum + active_entry.data;
                end

                TX_CTRL_CHECKSUM: if (tx_ready) begin
                    tx_data                 <= checksum;
                    tx_valid                <= 1;
                    tx_state                <= TX_CTRL_IDLE;
                end
            endcase
        end
    end

endmodule
