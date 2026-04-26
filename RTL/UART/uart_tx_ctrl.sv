timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;

module uart_tx_ctrl(
    input   logic               rstn,
    input   logic               clk,

    input   uart_res_t          res,
    mmio_out_interface.sink     mmio_out,

    input   logic               tx_ready,
    input   logic               flush,

    output  logic  [7:0]        tx_data,
    output  logic               tx_valid
);

    // ---------------- ACK/NAK -----------------

    logic                       res_valid;
    uart_res_t                  res_reg;
    logic                       res_consume;

    always_ff @(posedge clk) begin
        if (!rstn) begin
            res_valid           <= 0;
            res_reg             <= RES_STBY;
        end
        else begin
            if (res == RES_ACK || res == RES_NAK) begin
                res_valid       <= 1;
                res_reg         <= res;
            end
            else if (res_consume) begin
                res_valid       <= 0;
            end
        end
    end

    // ---------------- Overflow ----------------

    logic                       is_overflow;
    logic                       overflow_valid;
    logic [7:0]                 overflow_count;
    logic                       overflow_consume;

    always_ff @(posedge clk) begin
        if (!rstn || flush) begin
            overflow_valid      <= 0;
            overflow_count      <= 8'd0;
        end
        else begin
            if (is_overflow) begin
                overflow_valid  <= 1;

                if (overflow_valid && !overflow_consume) begin
                    if (overflow_count != 8'hFF)
                        overflow_count <= overflow_count + 1;
                end
                else begin
                    overflow_count <= 8'd1;
                end
            end
            else if (overflow_consume) begin
                overflow_valid  <= 0;
                overflow_count  <= 8'd0;
            end
        end
    end

    // --------- TX FIFO (Ring Buffer) ---------

    (* ram_style="distributed" *) logic [$bits(uart_tx_entry_t)-1:0] tx_fifo[0:PRINT_FIFO_SIZE-1];

    logic [PRINT_FIFO_BITS:0]   rd_ptr, wr_ptr; // MSB Indicates Wrap Bit
    logic                       fifo_empty, fifo_full;

    always_comb begin
        fifo_empty              = (rd_ptr == wr_ptr);
        fifo_full               = (wr_ptr[PRINT_FIFO_BITS]     != rd_ptr[PRINT_FIFO_BITS]) &&
                                  (wr_ptr[PRINT_FIFO_BITS-1:0] == rd_ptr[PRINT_FIFO_BITS-1:0]);
    end

    assign is_overflow          = (mmio_out.boot_valid || mmio_out.print_valid || mmio_out.exit_valid) &&
                                  (fifo_full || overflow_valid);

    always_ff @(posedge clk) begin
        if (!rstn || flush) begin
            wr_ptr  <= '0;
        end
        else if (!fifo_full && !overflow_valid) begin
            if (mmio_out.boot_valid) begin
                tx_fifo[wr_ptr[PRINT_FIFO_BITS-1:0]] <= {RES_BOOT, 3'd0, 8'd0};
                wr_ptr                               <= wr_ptr + 1;
            end
            else if (mmio_out.print_valid) begin
                tx_fifo[wr_ptr[PRINT_FIFO_BITS-1:0]] <= {RES_PRINT, 3'd1, mmio_out.print_data[7:0]};
                wr_ptr                               <= wr_ptr + 1;
            end
            else if (mmio_out.exit_valid) begin
                tx_fifo[wr_ptr[PRINT_FIFO_BITS-1:0]] <= {RES_EXIT, 3'd1, mmio_out.exit_code};
                wr_ptr                               <= wr_ptr + 1;
            end
        end
    end

    // ------------- TX Controller -------------

    uart_tx_ctrl_t              tx_state;

    uart_tx_entry_t             active_entry;
    uart_tx_entry_t             res_entry;
    uart_tx_entry_t             overflow_entry;
    logic [7:0]                 checksum;

    always_comb begin
        res_entry.res           = res_reg;
        res_entry.len           = 3'd0;
        res_entry.data          = 8'd0;

        overflow_entry.res      = RES_OVERFLOW;
        overflow_entry.len      = 3'd1;
        overflow_entry.data     = overflow_count;
    end

    always_comb begin
        res_consume             = 0;
        overflow_consume        = 0;

        if ((tx_state == TX_CTRL_IDLE) && !tx_valid) begin
            if (res_valid) begin
                res_consume     = 1;
            end
            else if (fifo_empty && overflow_valid) begin
                overflow_consume = 1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rstn || flush) begin
            rd_ptr              <= '0;

            tx_state            <= TX_CTRL_IDLE;
            tx_data             <= '0;
            tx_valid            <= 0;

            active_entry        <= '0;

            checksum            <= '0;
        end
        else begin
            unique case (tx_state)
                TX_CTRL_IDLE: begin
                    if (tx_valid) begin
                        if (tx_ready) begin
                            tx_data             <= '0;
                            tx_valid            <= 0;

                            checksum            <= '0;
                        end
                    end
                    else begin
                        if (res_consume) begin
                            active_entry        <= res_entry;

                            tx_data             <= START_FLAG;
                            tx_valid            <= 1;
                            tx_state            <= TX_CTRL_RES;

                            checksum            <= START_FLAG;
                        end
                        else if (!fifo_empty && !is_overflow) begin
                            active_entry        <= uart_tx_entry_t'(tx_fifo[rd_ptr[PRINT_FIFO_BITS-1:0]]);
                            rd_ptr              <= rd_ptr + 1;

                            tx_data             <= START_FLAG;
                            tx_valid            <= 1;
                            tx_state            <= TX_CTRL_RES;

                            checksum            <= START_FLAG;
                        end
                        else if (overflow_consume) begin
                            active_entry        <= overflow_entry;

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
                end

                TX_CTRL_RES:            if (tx_ready) begin
                    tx_data                 <= active_entry.res;
                    tx_valid                <= 1;
                    tx_state                <= TX_CTRL_LEN;

                    checksum                <= checksum + active_entry.res;
                end

                TX_CTRL_LEN:            if (tx_ready) begin
                    tx_data                 <= active_entry.len;
                    tx_valid                <= 1;
                    tx_state                <= (active_entry.len == 3'd0) ? TX_CTRL_CHECKSUM : TX_CTRL_PAYLOAD;

                    checksum                <= checksum + active_entry.len;
                end

                TX_CTRL_PAYLOAD:        if (tx_ready) begin
                    tx_data                 <= active_entry.data;
                    tx_valid                <= 1;
                    tx_state                <= TX_CTRL_CHECKSUM;

                    checksum                <= checksum + active_entry.data;
                end

                TX_CTRL_CHECKSUM:       if (tx_ready) begin
                    tx_data                 <= checksum;
                    tx_valid                <= 1;
                    tx_state                <= TX_CTRL_IDLE;
                end
            endcase
        end
    end

endmodule
