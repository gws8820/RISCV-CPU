timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;

module uart_tx_ctrl(
    input   logic           rstn,
    input   logic           clk,

    input   uart_res_t      res,
    input   logic           print_en,
    input   logic  [31:0]   print_data,

    input   logic           tx_ready,
    
    output  logic  [7:0]    tx_data,
    output  logic           tx_valid
);

    // --------- TX FIFO (Ring Buffer) ---------

    uart_tx_entry_t         tx_fifo[0:FIFO_SIZE-1];

    logic [FIFO_BITS:0]     rd_ptr, wr_ptr; // MSB Indicates Wrap Bit
    logic                   fifo_empty, fifo_full;

    always_comb begin
        fifo_empty  = (rd_ptr == wr_ptr);
        fifo_full   = (wr_ptr[FIFO_BITS]      != rd_ptr[FIFO_BITS]) &&
                      (wr_ptr[FIFO_BITS-1:0]  == rd_ptr[FIFO_BITS-1:0]);
    end

    always_ff @(posedge clk) begin
        if (!rstn) begin
            wr_ptr  <= '0;
        end
        else if (!fifo_full) begin
            unique case (res)
                RES_ACK, RES_NAK: begin
                    tx_fifo[wr_ptr[FIFO_BITS-1:0]].res      <= res;
                    tx_fifo[wr_ptr[FIFO_BITS-1:0]].len      <= '0;
                    tx_fifo[wr_ptr[FIFO_BITS-1:0]].data     <= '0;

                    wr_ptr                                  <= wr_ptr + 1;
                end
                default: begin
                    if (print_en) begin
                        tx_fifo[wr_ptr[FIFO_BITS-1:0]].res  <= RES_PRINT;
                        tx_fifo[wr_ptr[FIFO_BITS-1:0]].len  <= 3'd4;
                        tx_fifo[wr_ptr[FIFO_BITS-1:0]].data <= print_data;

                        wr_ptr                              <= wr_ptr + 1;
                    end
                end
            endcase
        end
    end

    // ------------- TX Controller (Byte Level) -------------

    uart_tx_ctrl_t          tx_state;
    uart_tx_entry_t         active_entry;

    logic [7:0]             data_len;
    logic [7:0]             data_counter;
    
    logic [7:0]             checksum;

    always_ff @(posedge clk) begin
        if (!rstn) begin
            rd_ptr          <= '0;

            tx_state        <= TX_CTRL_IDLE;
            tx_data         <= '0;
            tx_valid        <= 0;
            
            active_entry    <= '0;
            
            data_len        <= '0;
            data_counter    <= '0;
            
            checksum        <= '0;
        end
        else begin
            unique case (tx_state)
                TX_CTRL_IDLE: begin
                    data_len            <= 0;
                    data_counter        <= '0;

                    if (!fifo_empty && tx_ready) begin
                        active_entry    <= tx_fifo[rd_ptr[FIFO_BITS-1:0]];
                        rd_ptr          <= rd_ptr + 1;

                        tx_data         <= START_FLAG;
                        tx_valid        <= 1;
                        tx_state        <= TX_CTRL_RES;
                        
                        checksum        <= START_FLAG;
                    end
                    else begin
                        tx_data         <= '0;
                        tx_valid        <= 0;
                        tx_state        <= TX_CTRL_IDLE;
                        
                        checksum        <= '0;
                    end
                end

                TX_CTRL_RES: if (tx_ready) begin
                    tx_data             <= active_entry.res;
                    tx_valid            <= 1;
                    tx_state            <= TX_CTRL_LEN;
                    
                    checksum            <= checksum + active_entry.res;
                end

                TX_CTRL_LEN: if (tx_ready) begin
                    if (active_entry.len > 0) begin
                        data_len        <= active_entry.len;
                        tx_data         <= active_entry.len;
                        tx_valid        <= 1;
                        tx_state        <= TX_CTRL_PAYLOAD;
                        
                        checksum        <= checksum + active_entry.len;
                    end
                    else begin
                        tx_data         <= '0;
                        tx_valid        <= 1;
                        tx_state        <= TX_CTRL_CHECKSUM;
                        
                        checksum        <= checksum;
                    end
                end

                TX_CTRL_PAYLOAD: if (tx_ready) begin
                    tx_data             <= active_entry.data[data_counter*8 +: 8];
                    tx_valid            <= 1;
                    data_counter        <= data_counter + 1;

                    if (data_counter == data_len - 1)
                        tx_state        <= TX_CTRL_CHECKSUM;
                    else
                        tx_state        <= TX_CTRL_PAYLOAD;
                        
                    checksum            <= checksum + active_entry.data[data_counter*8 +: 8];
                end
                
                TX_CTRL_CHECKSUM: if (tx_ready) begin
                    tx_data             <= checksum;
                    tx_valid            <= 1;
                    tx_state            <= TX_CTRL_IDLE;
                end
            endcase
        end
    end

endmodule
