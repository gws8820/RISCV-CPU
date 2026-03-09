timeunit 1ns;
timeprecision 1ps;

import riscv_defines::*;

module riscv_cpu_fpga (
    // FPGA
    input   logic                   rstn_push, clk,
    output  logic                   rstn_led, start_led,
    
    // UART
    input   logic                   uart_rx,
    output  logic                   uart_tx
);

    logic                           rstn50;
    logic                           start;

    // ------------- Clocking -------------
    logic                           clk50_ibuf;
    logic                           clk50_buf;

    logic                           mmcm_locked;
    logic                           mmcm_reset;
    logic                           clk100_mmcm;
    logic                           clk100_buf;

    logic                           clkfb_mmcm;
    logic                           clkfb_buf;

    // Input Clock Buffer (50MHz)
    IBUF ibuf_sys_clk (
        .I  (clk),
        .O  (clk50_ibuf)
    );

    // Global Clock Buffer
    BUFG bufg_clk50 (
        .I  (clk50_ibuf),
        .O  (clk50_buf)
    );

    // Feedback Buffer for MMCM
    BUFG bufg_mmcm_fb (
        .I  (clkfb_mmcm),
        .O  (clkfb_buf)
    );

    // Output Clock Buffer (100MHz)
    BUFG bufg_clk100 (
        .I  (clk100_mmcm),
        .O  (clk100_buf)
    );

    // MMCM: 50MHz -> 100MHz
    // VCO = 50 * 15 / 1 = 750MHz (within 7-series MMCM VCO range)
    // CLKOUT0 = 750 / 7.5 = 100MHz
    
    assign mmcm_reset = ~rstn50;

    MMCME2_BASE #(
        .BANDWIDTH                  ("OPTIMIZED"),
        .CLKFBOUT_MULT_F            (15.0),
        .CLKFBOUT_PHASE             (0.0),
        .CLKIN1_PERIOD              (20.0),
        .DIVCLK_DIVIDE              (1),
        .CLKOUT0_DIVIDE_F           (7.5),
        .CLKOUT0_PHASE              (0.0),
        .CLKOUT0_DUTY_CYCLE         (0.5)
    ) mmcm_sys_clk (
        .CLKIN1                     (clk50_buf),
        .CLKFBIN                    (clkfb_buf),
        .RST                        (mmcm_reset),
        .PWRDWN                     (0),
        .LOCKED                     (mmcm_locked),
        .CLKFBOUT                   (clkfb_mmcm),
        .CLKOUT0                    (clk100_mmcm)
    );
    
    // ----------- FPGA Signals -----------

    // CDC synchronizers (mark as async regs for better placement/handling)
    (* ASYNC_REG = "TRUE" *) logic  rstn_push_reg, rstn_push_sync;
    logic [DEBOUNCE_BITS-1:0]       rstn_debounce_cnt;

    initial begin
        rstn50                      = 0;
        rstn_debounce_cnt           = 0;
    end
     
    // 2-FF Synchronizer
    always_ff@(posedge clk50_buf) begin
        rstn_push_reg               <= rstn_push;
        rstn_push_sync              <= rstn_push_reg;
    end

    always_ff@(posedge clk50_buf) begin
        if (rstn_push_sync != rstn50) begin  // Active Low
            if (rstn_debounce_cnt == DEBOUNCE_LIMIT - 1) begin
                rstn50              <= rstn_push_sync;
                rstn_debounce_cnt   <= 0;
            end
            else begin
                rstn_debounce_cnt   <= rstn_debounce_cnt + 1;
            end
        end
        else begin
            rstn_debounce_cnt       <= 0;
        end
    end

    (* ASYNC_REG = "TRUE" *) logic  rstn100_reg, rstn100_sync;
    
    // 2-FF Synchronizer
    always_ff @(posedge clk100_buf) begin
        rstn100_reg                 <= rstn50;
        rstn100_sync                <= rstn100_reg & mmcm_locked;
    end
    
    // LED (Active Low)
    always_comb begin
        rstn_led                    = !rstn100_sync;
        start_led                   = !start;
    end
    
    // --------- UART Controller ----------
    
    logic               prog_en;
    logic [31:0]        prog_addr;
    logic [31:0]        prog_data;

    logic               boot_en;
    logic               exit_en;
    logic [7:0]         exit_code;
    logic               print_en;
    logic [31:0]        print_data;

    logic               input_valid;
    logic [7:0]         input_data;
    logic               input_done;
    
    uart_controller uart_controller (
        .rstn           (rstn100_sync),
        .clk            (clk100_buf),
        .rx             (uart_rx),
        .tx             (uart_tx),
        
        .start          (start),
        
        .prog_en        (prog_en),
        .prog_addr      (prog_addr),
        .prog_data      (prog_data),
        
        .boot_en        (boot_en),
        .exit_en        (exit_en),
        .exit_code      (exit_code),
        .print_en       (print_en),
        .print_data     (print_data),
        .input_valid    (input_valid),
        .input_data     (input_data),
        .input_done     (input_done)
    );

    // ----------- RISC-V CPU -------------

    riscv_cpu_core  cpu_core (
        .start          (start),
        .clk            (clk100_buf),

        .prog_en        (prog_en),
        .prog_addr      (prog_addr),
        .prog_data      (prog_data),

        .boot_en        (boot_en),
        .exit_en        (exit_en),
        .exit_code      (exit_code),
        .print_en       (print_en),
        .print_data     (print_data),
        .input_valid    (input_valid),
        .input_data     (input_data),
        .input_done     (input_done)
    );
    
endmodule
