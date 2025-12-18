timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;

module uart_rx_ctrl(
    input   logic           rstn,
    input   logic           clk,

    input   logic  [7:0]    rx_data,
    input   logic           rx_valid,

    output  logic           start,
    output  logic           prog_en,
    output  logic  [31:0]   prog_addr,
    output  logic  [31:0]   prog_data,

    output  uart_res_t      res
);

    uart_rx_ctrl_t          rx_state;
    uart_cmd_t              cmd;

    logic [31:0]            base_addr;
    logic [2:0]             addr_counter;

    logic [7:0]             data_len;
    logic [7:0]             data_counter;
    logic [7:0]             data_buffer [0:255];

    logic [7:0]             checksum;

    always_ff @(posedge clk) begin
        if (!rstn) begin
            start           <= 0;
            prog_en         <= 0;
            prog_addr       <= '0;
            prog_data       <= '0;

            cmd             <= CMD_RESET;
            res             <= RES_STBY;

            rx_state        <= RX_CTRL_IDLE;

            base_addr       <= '0;
            addr_counter    <= '0;

            data_len        <= '0;
            data_counter    <= '0;

            checksum        <= '0;
        end
        else begin
            unique case (rx_state)
                RX_CTRL_IDLE: begin
                    cmd             <= CMD_RESET;
                    res             <= RES_STBY;

                    base_addr       <= '0;
                    addr_counter    <= '0;
                    data_len        <= '0;
                    data_counter    <= '0;

                    prog_en         <= 0;
                    prog_addr       <= '0;
                    prog_data       <= '0;

                    if (rx_valid) begin
                        if (rx_data == START_FLAG) begin
                            rx_state    <= RX_CTRL_CMD;
                            checksum    <= START_FLAG;
                        end
                        else begin
                            rx_state    <= RX_CTRL_IDLE;
                            checksum    <= '0;
                        end
                    end
                end

                RX_CTRL_CMD: if (rx_valid) begin
                    cmd             <= uart_cmd_t'(rx_data);
                    rx_state        <= RX_CTRL_LEN;
                    checksum        <= checksum + rx_data;
                end

                RX_CTRL_LEN: if (rx_valid) begin
                    if (rx_data == 0) begin                             // RESET or START
                        data_len    <= 0;
                        rx_state    <= RX_CTRL_CHECKSUM;
                    end
                    else if (rx_data >= 8 && (rx_data % 4) == 0) begin  // Data
                        data_len    <= rx_data - 4;
                        rx_state    <= RX_CTRL_PAYLOAD;
                    end
                    else begin                                          // Invalid
                        data_len    <= 0;
                        res         <= RES_NAK;
                        rx_state    <= RX_CTRL_IDLE;
                    end
                    
                    checksum        <= checksum + rx_data;
                end

                RX_CTRL_PAYLOAD: if (rx_valid) begin
                    if (addr_counter < 4) begin         // Address
                        base_addr[addr_counter*8 +: 8]  <= rx_data;
                        addr_counter                    <= addr_counter + 1;
                    end
                    else begin                          // Data
                        data_buffer[data_counter]       <= rx_data;
                        data_counter                    <= data_counter + 1;

                        if (data_counter == data_len - 1) begin
                            rx_state    <= RX_CTRL_CHECKSUM;
                        end
                        else begin
                            rx_state    <= RX_CTRL_PAYLOAD;
                        end
                    end
                    
                    checksum <= checksum + rx_data;
                end

                RX_CTRL_CHECKSUM: if (rx_valid) begin
                    addr_counter        <= 0;
                    data_counter        <= 0;

                    if (rx_data == checksum)
                        rx_state        <= RX_CTRL_BUSY;
                    else begin
                        res             <= RES_NAK;
                        rx_state        <= RX_CTRL_IDLE;
                    end
                end

                RX_CTRL_BUSY: begin
                    unique case (cmd)
                        CMD_RESET:  begin
                            start           <= 0;
                            res             <= RES_ACK;
                            rx_state        <= RX_CTRL_IDLE;
                        end
                        CMD_RUN:    begin
                            start           <= 1;
                            res             <= RES_ACK;
                            rx_state        <= RX_CTRL_IDLE;
                        end
                        CMD_WRITE:  begin
                            prog_en         <= 1;
                            prog_addr       <= base_addr + data_counter;
                            prog_data       <= {
                                data_buffer[data_counter + 3],
                                data_buffer[data_counter + 2],
                                data_buffer[data_counter + 1],
                                data_buffer[data_counter]
                            };

                            if (data_counter == data_len - 4) begin
                                res         <= RES_ACK;
                                rx_state    <= RX_CTRL_IDLE;
                            end
                            else begin
                                rx_state    <= RX_CTRL_BUSY;
                            end

                            data_counter    <= data_counter + 4;
                        end
                        default:    begin
                            res             <= RES_NAK;
                            rx_state        <= RX_CTRL_IDLE;
                        end
                    endcase
                end
            endcase
        end
    end

endmodule
