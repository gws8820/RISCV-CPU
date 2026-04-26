timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;

module uart_controller(
    input   logic                   rstn,
    input   logic                   clk,

    // UART Serial Pins
    input   logic                   rx,
    output  logic                   tx,

    // CPU Interface
    output  logic                   start,
    
    memory_init_interface.source    rom_init,
    mmio_out_interface.sink         mmio_out,
    mmio_in_interface.source        mmio_in
);

    // ------------ Baud Generator -------------

    logic                           sample_tick;
    logic                           baud_tick;

    uart_baud_gen baud_gen (
        .rstn                       (rstn),
        .clk                        (clk),
        .sample_tick                (sample_tick),
        .baud_tick                  (baud_tick)
    );

    // ---------------- RX PHY -----------------

    logic [7:0]                     rx_data;
    logic                           rx_valid;

    uart_rx_phy rx_phy (
        .rstn                       (rstn),
        .clk                        (clk),
        .sample_tick                (sample_tick),

        .rx                         (rx),

        .rx_data                    (rx_data),
        .rx_valid                   (rx_valid)
    );

    // ------------- RX Controller -------------

    uart_res_t                      res;
    logic                           flush;

    uart_rx_ctrl rx_ctrl (
        .rstn                       (rstn),
        .clk                        (clk),

        .rx_data                    (rx_data),
        .rx_valid                   (rx_valid),

        .start                      (start),

        .rom_init                   (rom_init),
        .mmio_in                    (mmio_in),

        .res                        (res),
        .flush                      (flush)
    );

    // ---------------- TX PHY -----------------

    logic [7:0]                     tx_data_byte;
    logic                           tx_data_valid;
    logic                           tx_ready;

    uart_tx_phy tx_phy (
        .rstn                       (rstn),
        .clk                        (clk),
        .baud_tick                  (baud_tick),

        .tx_data                    (tx_data_byte),
        .tx_valid                   (tx_data_valid),
        .tx_ready                   (tx_ready),

        .tx                         (tx)
    );

    // ------------- TX Controller -------------

    uart_tx_ctrl tx_ctrl (
        .rstn                       (rstn),
        .clk                        (clk),

        .res                        (res),
        .mmio_out                   (mmio_out),

        .tx_ready                   (tx_ready),
        .flush                      (flush),

        .tx_data                    (tx_data_byte),
        .tx_valid                   (tx_data_valid)
    );

endmodule
