timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;

module uart_controller(
    input   logic           rstn,
    input   logic           clk,

    // UART Serial Pins
    input   logic           rx,
    output  logic           tx,

    // CPU Interface
    output  logic           start,
    
    output  logic           prog_en,
    output  logic [31:0]    prog_addr,
    output  logic [31:0]    prog_data,

    input   logic           print_en,
    input   logic [31:0]    print_data
);

    // ------------ Baud Generator -------------

    logic                   sample_tick;
    logic                   baud_tick;

    uart_baud_gen baud_gen (
        .rstn               (rstn),
        .clk                (clk),
        .sample_tick        (sample_tick),
        .baud_tick          (baud_tick)
    );

    // ---------------- RX PHY -----------------

    logic [7:0]             rx_data;
    logic                   rx_valid;

    uart_rx_phy rx_phy (
        .rstn               (rstn),
        .clk                (clk),
        .sample_tick        (sample_tick),

        .rx                 (rx),

        .rx_data            (rx_data),
        .rx_valid           (rx_valid)
    );

    // ------------- RX Controller -------------

    uart_res_t              res;

    uart_rx_ctrl rx_ctrl (
        .rstn               (rstn),
        .clk                (clk),

        .rx_data            (rx_data),
        .rx_valid           (rx_valid),

        .start              (start),
        .prog_en            (prog_en),
        .prog_addr          (prog_addr),
        .prog_data          (prog_data),

        .res                (res)
    );

    // ---------------- TX PHY -----------------

    logic [7:0]             tx_data_byte;
    logic                   tx_data_valid;
    logic                   tx_ready;

    uart_tx_phy tx_phy (
        .rstn               (rstn),
        .clk                (clk),
        .baud_tick          (baud_tick),

        .tx_data            (tx_data_byte),
        .tx_valid           (tx_data_valid),
        .tx_ready           (tx_ready),

        .tx                 (tx)
    );

    // ------------- TX Controller -------------

    uart_tx_ctrl tx_ctrl (
        .rstn               (rstn),
        .clk                (clk),

        .res                (res),
        .print_en           (print_en),
        .print_data         (print_data),

        .tx_ready           (tx_ready),
        
        .tx_data            (tx_data_byte),
        .tx_valid           (tx_data_valid)
    );

endmodule