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

    output  logic           input_valid,
    output  logic  [7:0]    input_data,
    input   logic           input_done,

    output  uart_res_t      res
);

    // -------------- Input FIFO --------------

    (* ram_style="distributed" *) logic [7:0] input_fifo [0:INPUT_FIFO_SIZE-1];

    logic [INPUT_FIFO_BITS:0]   rd_ptr, wr_ptr; // MSB Indicates Wrap Bit
    logic                       fifo_empty, fifo_full;

    always_comb begin
        fifo_empty      =   (rd_ptr == wr_ptr);
        fifo_full       =   (wr_ptr[INPUT_FIFO_BITS]      != rd_ptr[INPUT_FIFO_BITS]) &&
                            (wr_ptr[INPUT_FIFO_BITS-1:0]  == rd_ptr[INPUT_FIFO_BITS-1:0]);
    end

    assign input_valid  = !fifo_empty;
    assign input_data   = input_fifo[rd_ptr[INPUT_FIFO_BITS-1:0]];


    // ------------- RX Controller -------------

    (* ram_style="distributed" *) logic [7:0] data_buffer [0:255];

    uart_rx_ctrl_t          rx_state;
    uart_cmd_t              cmd;

    logic [31:0]            base_addr;
    logic [2:0]             addr_counter;

    logic [7:0]             data_len;
    logic [7:0]             data_counter;
    
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

            rd_ptr          <= '0;
            wr_ptr          <= '0;
        end
        else begin
            if (input_done && !fifo_empty)
                rd_ptr <= rd_ptr + 1;

            unique case (rx_state)
                RX_CTRL_IDLE: begin
                    cmd             <= CMD_RESET;
                    res             <= RES_STBY;

                    base_addr       <= '0;
                    addr_counter    <= '0;
                    data_len        <= '0;
                    data_counter    <= '0;

                    prog_en         <= 0;

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
                    else if (cmd == CMD_INPUT) begin                    // Input data
                        data_len    <= rx_data;
                        rx_state    <= RX_CTRL_PAYLOAD;
                    end
                    else if (rx_data >= 8 && (rx_data % 4) == 0) begin  // Write data
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
                    if (cmd == CMD_INPUT) begin         // Input
                        data_buffer[data_counter]       <= rx_data;
                        data_counter                    <= data_counter + 1;

                        if (data_counter == data_len - 1)
                            rx_state    <= RX_CTRL_CHECKSUM;
                    end
                    else if (addr_counter < 4) begin    // Address
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
                            rd_ptr          <= '0;
                            wr_ptr          <= '0;
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
                        CMD_INPUT:  begin
                            if (!fifo_full) begin
                                input_fifo[wr_ptr[INPUT_FIFO_BITS-1:0]] <= data_buffer[data_counter];
                                wr_ptr                                  <= wr_ptr + 1;
                                data_counter                    <= data_counter + 1;

                                if (data_counter == data_len - 1) begin
                                    res         <= RES_ACK;
                                    rx_state    <= RX_CTRL_IDLE;
                                end
                            end
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
