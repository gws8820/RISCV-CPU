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

    logic                           rstn;
    logic                           start;

    // ----------- Clock Buffer -----------
    logic                           clk_ibuf;
    logic                           clk_buf;

    IBUF ibuf_sys_clk (
        .I  (clk),
        .O  (clk_ibuf)
    );
    BUFG bufg_sys_clk (
        .I  (clk_ibuf),
        .O  (clk_buf)
    );
    
    // ----------- FPGA Signals -----------

    logic                           rstn_push_reg, rstn_push_sync;
    logic [DEBOUNCE_BITS-1:0]       rstn_debounce_cnt;
    
    initial begin
        rstn                        = 0;
        rstn_debounce_cnt           = 0;
    end
     
    // 2-FF Synchronizer
    always_ff@(posedge clk_buf) begin
        rstn_push_reg               <= rstn_push;
        rstn_push_sync              <= rstn_push_reg;
    end

    always_ff@(posedge clk_buf) begin
        if (rstn_push_sync != rstn) begin  // Active Low
            if (rstn_debounce_cnt == DEBOUNCE_LIMIT - 1) begin
                rstn                <= rstn_push_sync;
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
    
    always_comb begin
        rstn_led                    = !rstn;
        start_led                   = !start;
    end
    
    // --------- UART Controller ----------
    
    logic               prog_en;
    logic [31:0]        prog_addr;
    logic [31:0]        prog_data;

    logic               print_en;
    logic [31:0]        print_data;
    
    uart_controller uart_controller (
        .rstn           (rstn),
        .clk            (clk_buf),
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
        .clk            (clk_buf),
        
        .prog_en        (prog_en),
        .prog_addr      (prog_addr),
        .prog_data      (prog_data),
        
        .print_en       (print_en),
        .print_data     (print_data)
    );
    
endmodule