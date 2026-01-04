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
    logic                           clk120_mmcm;
    logic                           clk120_buf;

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

    // Output Clock Buffer (120MHz)
    BUFG bufg_clk120 (
        .I  (clk120_mmcm),
        .O  (clk120_buf)
    );

    // MMCM: 50MHz -> 120MHz
    // VCO = 50 * 12 / 1 = 600MHz (within 7-series MMCM VCO range)
    // CLKOUT0 = 600 / 5 = 120MHz
    
    assign mmcm_reset = ~rstn50;

    MMCME2_BASE #(
        .BANDWIDTH                  ("OPTIMIZED"),
        .CLKFBOUT_MULT_F            (12.0),
        .CLKFBOUT_PHASE             (0.0),
        .CLKIN1_PERIOD              (20.0),
        .DIVCLK_DIVIDE              (1),
        .CLKOUT0_DIVIDE_F           (5.0),
        .CLKOUT0_PHASE              (0.0),
        .CLKOUT0_DUTY_CYCLE         (0.5)
    ) mmcm_sys_clk (
        .CLKIN1                     (clk50_buf),
        .CLKFBIN                    (clkfb_buf),
        .RST                        (mmcm_reset),
        .PWRDWN                     (0),
        .LOCKED                     (mmcm_locked),
        .CLKFBOUT                   (clkfb_mmcm),
        .CLKOUT0                    (clk120_mmcm)
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
    always_ff @(posedge clk120_buf) begin
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

    logic               print_en;
    logic [31:0]        print_data;
    
    uart_controller uart_controller (
        .rstn           (rstn100_sync),
        .clk            (clk120_buf),
        .rx             (uart_rx),
        .tx             (uart_tx),
        
        .start          (start),
        
        .prog_en        (prog_en),
        .prog_addr      (prog_addr),
        .prog_data      (prog_data),
        
        .print_en       (print_en),
        .print_data     (print_data)
    );
    
    // ----------- RISC-V CPU -------------
    
    riscv_cpu_core  cpu_core (
        .start          (start),
        .clk            (clk120_buf),
        
        .prog_en        (prog_en),
        .prog_addr      (prog_addr),
        .prog_data      (prog_data),
        
        .print_en       (print_en),
        .print_data     (print_data)
    );
    
endmodule