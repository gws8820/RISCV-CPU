timeunit 1ns;
timeprecision 1ps;

import uart_defines::*;
import riscv_defines::*;

module uart_testbench;
    localparam int CLK_PERIOD_NS = 10;
    localparam int SAMPLE_CNT    = CLK_FREQ / (BAUD_RATE * OVERSAMPLE_RATE);
    localparam int BIT_CYCLES    = SAMPLE_CNT * OVERSAMPLE_RATE;
    localparam int BIT_PERIOD_NS = BIT_CYCLES * CLK_PERIOD_NS;
    localparam bit VERBOSE       = 0;

    logic clk;
    logic rstn;
    logic uart_rx;
    logic uart_tx;
    logic start;

    memory_init_interface rom_init();
    mmio_out_interface    mmio_out();
    mmio_in_interface     mmio_in();

    uart_controller dut (
        .rstn       (rstn),
        .clk        (clk),
        .rx         (uart_rx),
        .tx         (uart_tx),
        .start      (start),
        .rom_init   (rom_init),
        .mmio_out   (mmio_out),
        .mmio_in    (mmio_in)
    );

    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS / 2) clk = ~clk;
    end

    initial begin
        uart_rx              = 1;
        rstn                 = 0;
        mmio_out.boot_valid  = 0;
        mmio_out.exit_valid  = 0;
        mmio_out.exit_code   = 0;
        mmio_out.print_valid = 0;
        mmio_out.print_data  = 0;
        mmio_in.ready        = 0;

        repeat (20) @(posedge clk);
        rstn = 1;
        repeat (20) @(posedge clk);

        test_reset_ack();
        test_write_ack_and_rom_init();
        test_input_ack_and_fifo();
        test_mmio_frames();
        test_exit_after_queued_prints();
        test_print_overflow_frame();

        $display("[PASS] UART controller/PHY integration test completed.");
        $finish;
    end

    initial begin
        #2000ms;
        fail("UART testbench timed out");
    end

    always @(posedge clk) begin
        if (dut.rx_valid)
            if (VERBOSE) $display("[%0t] DUT RX byte 0x%02h", $time, dut.rx_data);
        if (dut.tx_ready && dut.tx_data_valid)
            if (VERBOSE) $display("[%0t] DUT TX ready state=%0d valid=%0b data=0x%02h checksum=0x%02h",
                                  $time, dut.tx_ctrl.tx_state, dut.tx_data_valid, dut.tx_data_byte, dut.tx_ctrl.checksum);
        if (dut.res == RES_ACK || dut.res == RES_NAK)
            if (VERBOSE) $display("[%0t] DUT response status 0x%02h", $time, dut.res);
    end

    task automatic fail(input string msg);
        $fatal(1, "[FAIL] %s", msg);
    endtask

    function automatic logic [7:0] checksum3(
        input logic [7:0] a,
        input logic [7:0] b,
        input logic [7:0] c
    );
        checksum3 = a + b + c;
    endfunction

    task automatic uart_send_byte(input logic [7:0] data);
        uart_rx = 0;
        #(BIT_PERIOD_NS);
        for (int i = 0; i < 8; i++) begin
            uart_rx = data[i];
            #(BIT_PERIOD_NS);
        end
        uart_rx = 1;
        #(BIT_PERIOD_NS);
    endtask

    task automatic uart_recv_byte(output logic [7:0] data);
        @(negedge uart_tx);
        #(BIT_PERIOD_NS + (BIT_PERIOD_NS / 2));
        for (int i = 0; i < 8; i++) begin
            data[i] = uart_tx;
            #(BIT_PERIOD_NS);
        end
        if (uart_tx !== 1'b1)
            fail($sformatf("UART TX stop bit was not high after byte 0x%02h", data));
        if (VERBOSE) $display("[%0t] HOST RX byte 0x%02h", $time, data);
    endtask

    task automatic send_frame(
        input logic [7:0] cmd,
        input logic [7:0] len,
        input logic [7:0] payload [0:255]
    );
        logic [7:0] sum;

        sum = START_FLAG + cmd + len;
        uart_send_byte(START_FLAG);
        uart_send_byte(cmd);
        uart_send_byte(len);
        for (int i = 0; i < len; i++) begin
            sum += payload[i];
            uart_send_byte(payload[i]);
        end
        uart_send_byte(sum);
    endtask

    task automatic recv_frame(
        output logic [7:0] res,
        output logic [7:0] len,
        output logic [7:0] payload [0:255]
    );
        logic [7:0] byte_data;
        logic [7:0] sum;

        uart_recv_byte(byte_data);
        if (byte_data != START_FLAG)
            fail($sformatf("Expected START_FLAG, got 0x%02h", byte_data));

        sum = byte_data;
        uart_recv_byte(res);
        sum += res;
        uart_recv_byte(len);
        sum += len;
        for (int i = 0; i < len; i++) begin
            uart_recv_byte(payload[i]);
            sum += payload[i];
        end
        uart_recv_byte(byte_data);
        if (byte_data != sum)
            fail($sformatf("Checksum mismatch: expected 0x%02h, got 0x%02h", sum, byte_data));
    endtask

    task automatic expect_frame(
        input logic [7:0] exp_res,
        input logic [7:0] exp_len,
        input logic [7:0] exp_data
    );
        logic [7:0] res;
        logic [7:0] len;
        logic [7:0] payload [0:255];

        recv_frame(res, len, payload);
        if (res != exp_res)
            fail($sformatf("Expected response 0x%02h, got 0x%02h", exp_res, res));
        if (len != exp_len)
            fail($sformatf("Expected length %0d, got %0d", exp_len, len));
        if ((exp_len != 0) && (payload[0] != exp_data))
            fail($sformatf("Expected payload 0x%02h, got 0x%02h", exp_data, payload[0]));
    endtask

    task automatic send_and_expect(
        input logic [7:0] cmd,
        input logic [7:0] len,
        input logic [7:0] payload [0:255],
        input logic [7:0] exp_res,
        input logic [7:0] exp_len,
        input logic [7:0] exp_data
    );
        fork
            begin
                send_frame(cmd, len, payload);
            end
            begin
                expect_frame(exp_res, exp_len, exp_data);
            end
        join
    endtask

    task automatic test_reset_ack();
        logic [7:0] payload [0:255];

        send_and_expect(CMD_RESET, 8'd0, payload, RES_ACK, 8'd0, 8'h00);
        if (start !== 1'b0)
            fail("RESET command did not clear start");
        $display("[PASS] RESET command ACK frame");
    endtask

    task automatic test_write_ack_and_rom_init();
        logic [7:0] payload [0:255];
        int writes;

        payload[0] = 8'h10;
        payload[1] = 8'h00;
        payload[2] = 8'h00;
        payload[3] = 8'h00;
        payload[4] = 8'h78;
        payload[5] = 8'h56;
        payload[6] = 8'h34;
        payload[7] = 8'h12;

        writes = 0;
        fork
            begin
                send_frame(CMD_WRITE, 8'd8, payload);
            end
            begin
                repeat (200000) begin
                    @(posedge clk);
                    if (rom_init.write_enable) begin
                        writes++;
                        if (rom_init.write_addr != 32'h0000_0010)
                            fail($sformatf("Unexpected ROM write address 0x%08h", rom_init.write_addr));
                        if (rom_init.write_data != 32'h1234_5678)
                            fail($sformatf("Unexpected ROM write data 0x%08h", rom_init.write_data));
                    end
                end
            end
            begin
                expect_frame(RES_ACK, 8'd0, 8'h00);
            end
        join
        if (writes != 1)
            fail($sformatf("Expected one ROM init write, saw %0d", writes));
        $display("[PASS] WRITE command ACK and little-endian ROM write");
    endtask

    task automatic test_input_ack_and_fifo();
        logic [7:0] payload [0:255];
        logic [7:0] expected [0:2];

        payload[0] = "H";
        payload[1] = "i";
        payload[2] = 8'h0a;
        expected[0] = payload[0];
        expected[1] = payload[1];
        expected[2] = payload[2];

        send_and_expect(CMD_INPUT, 8'd3, payload, RES_ACK, 8'd0, 8'h00);

        for (int i = 0; i < 3; i++) begin
            wait (mmio_in.valid);
            if (mmio_in.data != expected[i])
                fail($sformatf("Input FIFO byte %0d expected 0x%02h, got 0x%02h", i, expected[i], mmio_in.data));
            @(posedge clk);
            mmio_in.ready = 1;
            @(posedge clk);
            mmio_in.ready = 0;
            @(posedge clk);
        end
        $display("[PASS] INPUT command ACK and FIFO order");
    endtask

    task automatic pulse_boot();
        @(posedge clk);
        mmio_out.boot_valid = 1;
        @(posedge clk);
        mmio_out.boot_valid = 0;
    endtask

    task automatic pulse_print(input logic [7:0] ch);
        @(posedge clk);
        mmio_out.print_data  = {24'b0, ch};
        mmio_out.print_valid = 1;
        @(posedge clk);
        mmio_out.print_valid = 0;
    endtask

    task automatic pulse_exit(input logic [7:0] code);
        @(posedge clk);
        mmio_out.exit_code  = code;
        mmio_out.exit_valid = 1;
        @(posedge clk);
        mmio_out.exit_valid = 0;
    endtask

    task automatic test_mmio_frames();
        pulse_boot();
        expect_frame(RES_BOOT, 8'd0, 8'h00);

        pulse_print("Z");
        expect_frame(RES_PRINT, 8'd1, "Z");

        pulse_exit(8'h07);
        expect_frame(RES_EXIT, 8'd1, 8'h07);

        $display("[PASS] BOOT/PRINT/EXIT response frames");
    endtask

    task automatic test_exit_after_queued_prints();
        pulse_print("A");
        pulse_print("B");
        pulse_exit(8'h00);

        expect_frame(RES_PRINT, 8'd1, "A");
        expect_frame(RES_PRINT, 8'd1, "B");
        expect_frame(RES_EXIT, 8'd1, 8'h00);

        $display("[PASS] EXIT stays ordered after queued PRINT frames");
    endtask

    task automatic test_print_overflow_frame();
        logic [7:0] res;
        logic [7:0] len;
        logic [7:0] payload [0:255];
        logic       saw_overflow;

        fork
            begin
                @(posedge clk);
                for (int i = 0; i < (PRINT_FIFO_SIZE + 4); i++) begin
                    mmio_out.print_data  = {24'b0, i[7:0]};
                    mmio_out.print_valid = 1;
                    @(posedge clk);
                end
                mmio_out.print_valid = 0;
            end
            begin
                recv_frame(res, len, payload);
            end
        join

        saw_overflow = 0;
        for (int i = 0; i < (PRINT_FIFO_SIZE + 8); i++) begin
            if (i != 0)
                recv_frame(res, len, payload);

            if (res == RES_PRINT) begin
                if (len != 8'd1)
                    fail($sformatf("Expected PRINT length 1, got %0d", len));
            end
            else if (res == RES_OVERFLOW) begin
                if (len != 8'd1)
                    fail($sformatf("Expected OVERFLOW length 1, got %0d", len));
                if (payload[0] == 8'd0)
                    fail("Overflow count should be nonzero");

                saw_overflow = 1;
                break;
            end
            else begin
                fail($sformatf("Expected PRINT or OVERFLOW frame, got 0x%02h", res));
            end
        end

        if (!saw_overflow)
            fail("Expected OVERFLOW frame after accepted PRINT frames");

        $display("[PASS] PRINT FIFO overflow response frame");
    endtask
endmodule
