timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module riscv_cpu_fpga (
    // FPGA
    input   logic                       rstn_push,
    output  logic                       rstn_led, start_led,
    
    // UART
    input   logic                       uart_rx,
    output  logic                       uart_tx,

    // Zynq PS DDR / Fixed IO
    inout   wire    [14:0]              DDR_addr,
    inout   wire    [2:0]               DDR_ba,
    inout   wire                        DDR_cas_n,
    inout   wire                        DDR_ck_n,
    inout   wire                        DDR_ck_p,
    inout   wire                        DDR_cke,
    inout   wire                        DDR_cs_n,
    inout   wire    [3:0]               DDR_dm,
    inout   wire    [31:0]              DDR_dq,
    inout   wire    [3:0]               DDR_dqs_n,
    inout   wire    [3:0]               DDR_dqs_p,
    inout   wire                        DDR_odt,
    inout   wire                        DDR_ras_n,
    inout   wire                        DDR_reset_n,
    inout   wire                        DDR_we_n,
    inout   wire                        FIXED_IO_ddr_vrn,
    inout   wire                        FIXED_IO_ddr_vrp,
    inout   wire    [53:0]              FIXED_IO_mio,
    inout   wire                        FIXED_IO_ps_clk,
    inout   wire                        FIXED_IO_ps_porb,
    inout   wire                        FIXED_IO_ps_srstb
);

    logic                               clk;
    logic                               rstn;
    logic                               start;
    
    // ---------- Zynq PS Wrapper ---------
    
    zynq_ps_wrapper zynq_ps (
        .DDR_addr                       (DDR_addr),
        .DDR_ba                         (DDR_ba),
        .DDR_cas_n                      (DDR_cas_n),
        .DDR_ck_n                       (DDR_ck_n),
        .DDR_ck_p                       (DDR_ck_p),
        .DDR_cke                        (DDR_cke),
        .DDR_cs_n                       (DDR_cs_n),
        .DDR_dm                         (DDR_dm),
        .DDR_dq                         (DDR_dq),
        .DDR_dqs_n                      (DDR_dqs_n),
        .DDR_dqs_p                      (DDR_dqs_p),
        .DDR_odt                        (DDR_odt),
        .DDR_ras_n                      (DDR_ras_n),
        .DDR_reset_n                    (DDR_reset_n),
        .DDR_we_n                       (DDR_we_n),
        .FCLK_CLK0                      (clk),              // 100MHz
        .FIXED_IO_ddr_vrn               (FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp               (FIXED_IO_ddr_vrp),
        .FIXED_IO_mio                   (FIXED_IO_mio),
        .FIXED_IO_ps_clk                (FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb               (FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb              (FIXED_IO_ps_srstb)
    );

    // ----------- FPGA Signals -----------

    // CDC synchronizers
    (* ASYNC_REG = "TRUE" *) logic      rstn_push_reg, rstn_push_sync;
    logic [DEBOUNCE_BITS-1:0]           rstn_debounce_cnt;

    always_ff@(posedge clk or negedge rstn_push) begin
        if (!rstn_push) begin
            rstn_push_reg               <= 0;
            rstn_push_sync              <= 0;
            rstn                        <= 0;
            rstn_debounce_cnt           <= '0;
        end
        else begin
            rstn_push_reg               <= rstn_push;
            rstn_push_sync              <= rstn_push_reg;

            if (!rstn_push_sync) begin
                rstn                    <= 0;
                rstn_debounce_cnt       <= '0;
            end
            else if (!rstn) begin
                if (rstn_debounce_cnt == DEBOUNCE_LIMIT - 1) begin
                    rstn                <= 1;
                    rstn_debounce_cnt   <= '0;
                end
                else begin
                    rstn_debounce_cnt   <= rstn_debounce_cnt + 1;
                end
            end
            else begin
                rstn_debounce_cnt       <= '0;
            end
        end
    end
    
    // LED (Active Low)
    always_comb begin
        rstn_led                        = !rstn;
        start_led                       = !start;
    end
    
    // --------- UART Controller ----------
    
    memory_init_interface               rom_init();
    mmio_out_interface                  mmio_out();
    mmio_in_interface                   mmio_in();
    
    uart_controller uart_controller (
        .rstn                           (rstn),
        .clk                            (clk),
        .rx                             (uart_rx),
        .tx                             (uart_tx),
        
        .start                          (start),
        
        .rom_init                       (rom_init),
        .mmio_out                       (mmio_out),
        .mmio_in                        (mmio_in)
    );

    // ------------ CPU Core ------------

    riscv_cpu_core  cpu_core (
        .start                          (start),
        .clk                            (clk),

        .rom_init                       (rom_init),
        .mmio_out                       (mmio_out),
        .mmio_in                        (mmio_in)
    );
    
endmodule
