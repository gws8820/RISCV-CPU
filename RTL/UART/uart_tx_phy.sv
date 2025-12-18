timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;

module uart_tx_phy(
    input   logic       rstn,
    input   logic       clk,
    input   logic       baud_tick,
    
    input   logic [7:0] tx_data,
    input   logic       tx_valid,
    
    output  logic       tx_ready,
    output  logic       tx
);

    logic [7:0]         tx_fifo[0:PHY_FIFO_SIZE-1];

    logic [PHY_FIFO_BITS:0] rd_ptr, wr_ptr; // MSB Indicates Wrap Bit
    logic               fifo_empty, fifo_full;
    always_comb begin
        fifo_empty      = (rd_ptr == wr_ptr);
        fifo_full       = (wr_ptr[PHY_FIFO_BITS]      != rd_ptr[PHY_FIFO_BITS]) && 
                          (wr_ptr[PHY_FIFO_BITS-1:0]  == rd_ptr[PHY_FIFO_BITS-1:0]);
                          
        tx_ready        = !fifo_full;
    end

    uart_tx_sync_t      tx_sync_state;

    logic [7:0]         active_entry;
    logic [2:0]         bit_counter;

    always_ff@(posedge clk) begin
        if (!rstn) begin
            tx                                      <= 1; // IDLE
            tx_sync_state                           <= TX_SYNC_IDLE;

            rd_ptr                                  <= '0;
            wr_ptr                                  <= '0;
            
            active_entry                            <= '0;
            bit_counter                             <= '0;
        end
        else begin
            if (!fifo_full && tx_valid) begin
                tx_fifo[wr_ptr[PHY_FIFO_BITS-1:0]]  <= tx_data;
                wr_ptr                              <= wr_ptr + 1;
            end

            if (baud_tick) begin
                unique case (tx_sync_state)
                    TX_SYNC_IDLE:   begin
                        bit_counter                 <= '0;
                        
                        if (!fifo_empty) begin
                            active_entry            <= tx_fifo[rd_ptr[PHY_FIFO_BITS-1:0]];
                            rd_ptr                  <= rd_ptr + 1;
                            

                            tx                      <= 0; // START
                            tx_sync_state           <= TX_SYNC_DATA;
                        end
                        else begin
                            tx                      <= 1;
                            tx_sync_state           <= TX_SYNC_IDLE;
                        end
                    end
                    TX_SYNC_DATA:   begin
                        tx                          <= active_entry[bit_counter];

                        unique case (bit_counter)
                            7:      begin
                                tx_sync_state       <= TX_SYNC_STOP;
                                bit_counter         <= '0;
                            end
                            default: begin
                                tx_sync_state       <= TX_SYNC_DATA;
                                bit_counter         <= bit_counter + 1;
                            end
                        endcase
                    end
                    TX_SYNC_STOP:   begin
                        tx                          <= 1;
                        tx_sync_state               <= TX_SYNC_IDLE;
                    end
                endcase
            end
        end
    end

endmodule