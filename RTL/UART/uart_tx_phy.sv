timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;

module uart_tx_phy(
    input   logic           rstn,
    input   logic           clk,
    input   logic           baud_tick,
    
    input   logic [7:0]     tx_data,
    input   logic           tx_valid,
    
    output  logic           tx_ready,
    output  logic           tx
);

    uart_tx_sync_t          tx_sync_state;

    logic [7:0]             active_entry;
    logic [7:0]             pending_entry;
    logic [2:0]             bit_counter;

    always_ff@(posedge clk) begin
        if (!rstn) begin
            tx                                      <= 1; // IDLE
            tx_sync_state                           <= TX_SYNC_IDLE;
            tx_ready                                <= 1;

            active_entry                            <= '0;
            pending_entry                           <= '0;
            bit_counter                             <= '0;
        end
        else begin
            if (tx_valid && tx_ready) begin
                pending_entry                       <= tx_data;
                tx_ready                            <= 0;
            end

            if (baud_tick) begin
                unique case (tx_sync_state)
                    TX_SYNC_IDLE:   begin
                        bit_counter                 <= '0;
                        
                        if (!tx_ready) begin
                            active_entry            <= pending_entry;
                            tx_ready                <= 1;
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
