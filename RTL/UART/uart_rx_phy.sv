timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;

module uart_rx_phy(
    input   logic       rstn,
    input   logic       clk,
    input   logic       sample_tick,
    
    input   logic       rx,

    output  logic [7:0] rx_data,
    output  logic       rx_valid
);

    // 2-FF Synchronizer
    logic rx_reg, rx_sync;

    always_ff@(posedge clk) begin
        if (!rstn) begin
            rx_reg  <= 1;
            rx_sync <= 1;
        end
        else begin
            rx_reg  <= rx;
            rx_sync <= rx_reg;
        end
    end

    uart_rx_sync_t              rx_sync_state;

    logic [OVERSAMPLE_BITS-1:0] tick_counter;
    logic [2:0]                 bit_counter;
    logic [7:0]                 rx_shift;

    always_ff@(posedge clk)     begin
        if (!rstn) begin
            rx_sync_state                           <= RX_SYNC_IDLE;

            tick_counter                            <= '0;
            bit_counter                             <= '0;
            rx_shift                                <= '0;
            
            rx_data                                 <= '0;
            rx_valid                                <= 0;
        end
        else begin
            rx_valid                                <= 0;
            
            if (sample_tick)   begin
                unique case (rx_sync_state)
                    RX_SYNC_IDLE:   begin
                        tick_counter                <= 0;
                        bit_counter                 <= 0;
                        rx_shift                    <= 0;
    
                        rx_data                     <= 0;
                        rx_valid                    <= 0;
    
                        unique case (rx_sync)
                            0: rx_sync_state        <= RX_SYNC_START;
                            1: rx_sync_state        <= RX_SYNC_IDLE;
                        endcase
                    end
                    RX_SYNC_START:  begin
                        if (tick_counter == (OVERSAMPLE_RATE/2 - 1)) begin // CENTER ALIGNED
                            tick_counter            <= 0;
    
                            unique case (rx_sync)
                                0: rx_sync_state    <= RX_SYNC_DATA;
                                1: rx_sync_state    <= RX_SYNC_IDLE;
                            endcase
                        end
                        else begin
                            tick_counter            <= tick_counter + 1;
                        end
                    end
                    RX_SYNC_DATA:   begin
                        if (tick_counter == (OVERSAMPLE_RATE - 1)) begin
                            tick_counter            <= 0;
                            rx_shift                <= {rx_sync, rx_shift[7:1]};
    
                            unique case (bit_counter)
                                7:      begin
                                    rx_sync_state   <= RX_SYNC_STOP;
                                    bit_counter     <= 0;
                                end
                                default: begin
                                    rx_sync_state   <= RX_SYNC_DATA;
                                    bit_counter     <= bit_counter + 1;
                                end
                            endcase
                        end
                        else begin
                            tick_counter            <= tick_counter + 1;
                        end
                    end
                    RX_SYNC_STOP:   begin
                        if (tick_counter == (OVERSAMPLE_RATE - 1)) begin
                            tick_counter            <= 0;
                            rx_sync_state           <= RX_SYNC_IDLE;
    
                            unique case (rx_sync)
                                0:  begin
                                    rx_data         <= 0;
                                    rx_valid        <= 0;
                                end
                                1:  begin
                                    rx_data         <= rx_shift;
                                    rx_valid        <= 1;
                                end
                            endcase
                        end
                        else begin
                            tick_counter            <= tick_counter + 1;
                        end
                    end
                endcase
            end
        end
    end

endmodule