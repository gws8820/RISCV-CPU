# RISC-V CPU

[![riscv/learn](https://img.shields.io/badge/🎉%20Featured%20in-riscv%2Flearn-4A90D9?style=flat-square)](https://github.com/riscv/learn)
[![awesome-riscv](https://img.shields.io/badge/🎉%20Featured%20in-awesome--riscv-F5A623?style=flat-square)](https://github.com/suryakantamangaraj/awesome-riscv)

A 6-stage pipelined RISC-V processor core designed for FPGA deployment, featuring an integrated UART controller for system programming and debugging. Achieved **263.7 CoreMark** and **91.0 DMIPS** at 100 MHz.

## Table of Contents

- [Features](#features)
  - [ISA Support](#isa-support)
  - [Microarchitecture](#microarchitecture)
- [Clock Domain and Reset](#clock-domain-and-reset)
  - [Target FPGA](#target-fpga)
  - [Clock and Reset Signals](#clock-and-reset-signals)
  - [Reset Behavior](#reset-behavior)
- [Memory Specifications](#memory-specifications)
  - [Memory Map](#memory-map)
  - [ROM (Read-Only Memory)](#rom-read-only-memory)
  - [RAM (Random-Access Memory)](#ram-random-access-memory)
- [Performance Characteristics](#performance-characteristics)
  - [CoreMark Benchmark](#coremark-benchmark)
  - [Dhrystone 2.2 Benchmark](#dhrystone-22-benchmark)
  - [Hardware Multiplier & Divisor](#hardware-multiplier--divisor)
  - [Pipeline Performance](#pipeline-performance)
  - [Hazard Penalties](#hazard-penalties)
  - [Trap/Exception Penalties](#trapexception-penalties)
- [Supported Instructions](#supported-instructions)
  - [RV32I Base Integer Instructions](#rv32i-base-integer-instructions)
  - [RV32M Standard Extension](#rv32m-standard-extension)
  - [Other Extensions](#other-extensions)
- [CSR Registers](#csr-registers)
  - [Machine-Mode CSRs](#machine-mode-csrs)
  - [Read-Only CSRs](#read-only-csrs)
- [UART Subsystem](#uart-subsystem)
  - [Protocol Specification](#protocol-specification)
- [Software & Tools](#software--tools)
  - [Directory Structure](#directory-structure)
  - [Toolchain Requirements](#toolchain-requirements)
  - [`runtime/` — Common Bare-Metal Runtime](#runtime--common-bare-metal-runtime)
  - [`apps/firmware/` — Custom Test Firmware](#appsfirmware--custom-test-firmware)
  - [`apps/coremark/` — CoreMark Benchmark](#appscoremark--coremark-benchmark)
  - [`apps/dhrystone/` — Dhrystone Benchmark](#appsdhrystone--dhrystone-benchmark)
  - [`apps/riscv-tests/` — Official RISC-V Test Suite](#appsriscv-tests--official-risc-v-test-suite)
  - [`programmer/` — Host-Side UART Programming Tool](#programmer--host-side-uart-programming-tool)
  - [Typical Workflow](#typical-workflow)
- [Simulation](#simulation)
  - [Vivado GUI](#vivado-gui)
  - [Batch Script](#batch-script)
- [Directory Structure](#directory-structure-1)
- [License](#license)

## Features

### ISA Support
- **Base ISA**: RV32I (RISC-V 32-bit Integer Base Instruction Set)
- **Extensions**:
  - **M**: Integer Multiplication and Division
  - **Zicsr**: Control and Status Register (CSR) Instructions
  - **Zifencei**: Instruction-Fetch Fence (FENCE.I)

### Microarchitecture
![CPU Architecture Diagram](architecture.png)

- **Pipeline**: 6-stage (Fetch, Decode, Execute, Memory 1, Memory 2, Writeback)
  - **MEM1**: Memory Access & Store Align
  - **MEM2**: Data Ready (FPGA BRAM Latency) & Load Data Extend
- **Branch Prediction**:
  - **BHT (Branch History Table)**: 256 entries. Uses a 2-bit Saturating Counter (Strongly/Weakly Taken/Not Taken) to predict conditional branches. Implemented as LUTRAM.
  - **BTB (Branch Target Buffer)**: 256 entries. Stores Valid bit, Entry Type (Branch, Jump, Return), Tag, and Target Address. Implemented as LUTRAM.
  - **RAS (Return Address Stack)**: 32 entries. Push on JAL/JALR with call hint (`CFHINT_CALL`); pop on JALR with return hint (`CFHINT_RET`). Supports nested function calls.
  - **Prediction Logic**: For branches, `pred_taken = bht_taken && btb_hit`; for JAL/JALR, `pred_taken = btb_hit`. No pipeline stalls or flushes on a correct prediction.
- **Branch Resolution**:
  - **Branch Unit**: Resolution & validation in EX stage. Registers inputs for timing optimization (1-cycle latency).
  - **Recovery**: 3-cycle penalty on misprediction (Flush ID/EX/MEM1, redirect PC)
- **Hazard Handling**:
  - RAW hazards resolved by forwarding from MEM1/MEM2/WB to EX
  - Store-Data hazards resolved by forwarding from WB to MEM1
  - Load-Use hazards resolved by 2-cycle pipeline stall + WB to EX forwarding
  - Branch Misprediction resolved by pipeline flush
- **Trap/Exception Support**:
  - ECALL, EBREAK, MRET
  - Illegal Instruction
  - Instruction/Data Address Misalign
  - Instruction/Data Access Fault
- **Hardware Multiplier & Divisor**:
  - **Multiplier**: Implemented using inferred DSP blocks (via `(* use_dsp = "yes" *)` synthesis attribute).
  - **Divisor**: Implemented using a custom iterative shift-subtract logic (2x loop unrolled, 16 cycles for 32-bit division).

## Clock Domain and Reset

### Target FPGA
- **Board**: ALINX AX7Z020B (Zynq-7020)
- **Input Clock**: 50 MHz (onboard oscillator)
- **Internal Clock**: 100 MHz (via MMCM)

### Clock and Reset Signals
| Signal | Type | Description |
|--------|------|-------------|
| `clk`  | Input | System clock |
| `rstn_push` | Input | Active-low asynchronous reset (Button, synchronized with 2-FF + debounce) |
| `uart_rx` | Input | UART Receive Data |
| `uart_tx` | Output | UART Transmit Data |
| `rstn_led` | Output | Reset status LED (active when reset asserted) |
| `start_led` | Output | CPU run status LED (active when CPU running) |

### Reset Behavior
1.  **Hard Reset**: Physical button or MMCM lock.
2.  **Soft Reset**: Controlled via UART commands during programming.
3.  **Initialization**: PC resets to `0x00000000`, pipeline flushes.

## Memory Specifications

### Memory Map
| Region | Base Address | Size | Description |
|--------|-------------|------|-------------|
| **ROM** | `0x00000000` | 128 KB | Program ROM (`.text`, `.rodata`, `.data` load image) |
| **RAM** | `0x00020000` | 128 KB | Data RAM (`.data`, `.bss`, stack) |
| **Stack Top** | `0x00040000` | — | Top of RAM (stack grows downward) |
| **PRINT** | `0xFFFF0000` | — | MMIO: UART TX output (write) |
| **INPUT** | `0xFFFF0004` | — | MMIO: UART RX input (read) |

### ROM (Read-Only Memory)
- **Size**: 128 KB (32768 words)
- **Width**: 32-bit
- **Access**: Read-only from the CPU; writable via UART programmer before `RUN`
- **Contents**: Full firmware image. Instruction fetches, `.rodata` loads, and `.data` initialization reads come from ROM.

### RAM (Random-Access Memory)
- **Size**: 128 KB (32768 words)
- **Width**: 32-bit
- **Access**: Read/Write (byte-enable write strobe)
- **Initialization**: `crt0.S` copies `.data` from ROM to RAM and clears `.bss` before `main()`.
- **IO Mapping**:
  - Writes to `0xFFFF_0000` (`MMIO_PRINT_ADDR`) with `data[8] == 0` → `RES_PRINT` via UART TX.
  - Writes to `0xFFFF_0000` with `data[8] == 1` → `RES_EXIT` with `data[7:0]` as exit code.
  - Reads from `0xFFFF_0004` (`MMIO_INPUT_ADDR`) → returns `input_data` if RX FIFO non-empty, else `0xFFFFFFFF`. Polled by `getchar()` in syscalls.
- **Access Fault**: Stores to ROM and accesses outside ROM/RAM/MMIO trigger a Data Access Fault trap.

## Performance Characteristics

### CoreMark Benchmark

Measured on Zynq-7020 FPGA running at 100 MHz (RV32IM, `-O2`, `ITERATIONS=3000`).

| Metric | Value |
|--------|-------|
| **CoreMark Score** | 263.7 |
| **CoreMark/MHz** | 2.64 |

---

### Dhrystone 2.2 Benchmark

Reference measurement on Zynq-7020 FPGA running at 100 MHz (RV32IM, `-O2`, `NUMBER_OF_RUNS=100000`).
The current simulation sanity configuration uses `NUMBER_OF_RUNS=10`.

| Metric | Value |
|--------|-------|
| **Dhrystones/Second** | 160000 |
| **DMIPS** | 91.0 |
| **DMIPS/MHz** | 0.91 |

> DMIPS = Dhrystones/Second ÷ 1,757 (VAX 11/780 reference = 1 DMIPS)

---

### Hardware Multiplier & Divisor

**Multiplier**
- Inferred DSP48 blocks via `(* use_dsp = "yes" *)` synthesis attribute.
- 3-stage pipeline: result available 3 cycles after issue, causing a **3-cycle stall** (`MUL_COUNT = 3`).

**Divisor**
- Algorithm: Shift-compare-subtract. Handles signed/unsigned division and remainder, with special-case handling for divide-by-zero and signed overflow.
- 2x loop unrolled: computes **2 quotient bits per clock cycle** combinatorially.
- 32-bit division takes **17 cycles** total (1 setup + 16 compute), causing a **17-cycle stall** (`DIV_COUNT = 17`, `SHIFT_COUNT = 16`).

### Pipeline Performance
- **Ideal CPI**: 1.0
- **Actual CPI**: Depends on program characteristics (typically 1.1–1.5 due to hazards)

### Hazard Penalties
| Hazard Type | Penalty (Cycles) | Detection Stage | Notes |
|-------------|------------------|-----------------|-------|
| **Data Hazard (RAW)** | 0 | EX | Forwarding from MEM1/MEM2/WB to EX. Loads are excluded from MEM1/MEM2 path. |
| **Store-Data Hazard** | 0 | MEM1 | Forwarding from WB to MEM1 store data register |
| **Load-Use Hazard** | 2 | ID | Stall while load is in EX (`id_ex`) and again in MEM1 (`id_mem1`); 2 bubbles total; result forwarded from WB→EX |
| **Branch Prediction Hit** | 0 | IF | Zero penalty (Seamless execution) |
| **Branch Prediction Miss** | 3 | EX | Flush ID/EX/MEM1 stages; redirect PC to correct target |
| **Multiplication Stall** | 3 | EX | Pipeline stall during multiplication |
| **Division Stall** | 17 | EX | Pipeline stall during division |

### Trap/Exception Penalties
| Trap/Flush Type | Penalty (Cycles) | Processing Stage | Notes |
|-----------------|------------------|------------------|-------|
| **All Traps** | 3 | MEM1 | Flush ID/EX/MEM1/MEM2 stages, redirect to mtvec |
| **MRET** | 3 | MEM1 | Flush ID/EX/MEM1/MEM2 stages, restore PC from mepc |
| **FENCE.I** | 3 | MEM1 | Flush ID/EX/MEM1/MEM2 stages, instruction memory sync |

## Supported Instructions

### RV32I Base Integer Instructions
- **Arithmetic**: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
- **Immediate Arithmetic**: ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU
- **Load**: LB, LH, LW, LBU, LHU
- **Store**: SB, SH, SW
- **Branch**: BEQ, BNE, BLT, BGE, BLTU, BGEU
- **Jump**: JAL, JALR
- **Upper Immediate**: LUI, AUIPC
- **System**: ECALL, EBREAK, MRET, WFI (Hint, NOP)

### RV32M Standard Extension
- **Multiplication**: MUL, MULH, MULHSU, MULHU
- **Division**: DIV, DIVU, REM, REMU

### Other Extensions
- **Zicsr**: CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
- **Zifencei**: FENCE.I (Instruction cache/pipeline flush)

## CSR Registers

### Machine-Mode CSRs

| CSR Address | Name | Description |
|-------------|------|-------------|
| 0x300 | **mstatus** | Machine status register (MIE, MPIE bits) |
| 0x304 | **mie** | Machine interrupt-enable register |
| 0x305 | **mtvec** | Machine trap-handler base address (default: `0x400`) |
| 0x340 | **mscratch** | Machine scratch register for trap handlers |
| 0x341 | **mepc** | Machine exception program counter |
| 0x342 | **mcause** | Machine trap cause |
| 0x343 | **mtval** | Machine trap value (bad address or instruction) |
| 0x344 | **mip** | Machine interrupt-pending register |
| 0xB00 | **mcycle** | Cycle counter (lower 32 bits), auto-incremented every clock cycle |
| 0xB80 | **mcycleh** | Cycle counter (upper 32 bits) |
| 0xB02 | **minstret** | Instructions-retired counter (lower 32 bits), incremented per retired instruction |
| 0xB82 | **minstreth** | Instructions-retired counter (upper 32 bits) |

### Read-Only CSRs

| CSR Address | Name | Description |
|-------------|------|-------------|
| 0xF14 | **mhartid** | Hardware thread ID (hart ID = 0) |
| 0xC00 | **cycle** | Alias for mcycle (lower 32 bits) |
| 0xC80 | **cycleh** | Alias for mcycleh (upper 32 bits) |
| 0xC02 | **instret** | Alias for minstret (lower 32 bits) |
| 0xC82 | **instreth** | Alias for minstreth (upper 32 bits) |

## UART Subsystem

Integrated UART controller for communication and system control.

- **System Programmer**: Loads compiled programs (`.hex`) into Program ROM.
- **Standard Output**: MMIO-based character output; `putchar`/`printf` write characters to `MMIO_PRINT_ADDR`, sent to host as `RES_PRINT` packets.
- **Standard Input**: MMIO-based character input; host sends bytes via `CMD_INPUT`, stored in `INPUT_FIFO`; `getchar`/`scanf` poll `MMIO_INPUT_ADDR` until a byte is available.

### Protocol Specification

#### 1. Configuration

| Parameter | Value |
|:---|:---|
| **Baud Rate** | 115200 bps |
| **Data Bits** | 8 bits |
| **Stop Bits** | 1 bit |
| **Parity** | None |
| **Oversampling** | 16x |

**FIFO Sizes**

| FIFO | Size | Description |
|:---|:---|:---|
| `INPUT_FIFO` | 64 entries | CPU input buffer: stores bytes received via `CMD_INPUT`, read by CPU via `MMIO_INPUT_ADDR`. Flushed on `CMD_RESET`. |
| `PRINT_FIFO` | 2048 entries | CPU output buffer: queues `RES_BOOT`/`RES_PRINT`/`RES_EXIT` packets for UART TX. Flushed on `CMD_RESET`. |

#### 2. Packet Structure

**RX Packet (Host → FPGA)**

| START | CMD | LEN | PAYLOAD | CHECKSUM |
| :---: | :---: | :---: | :---: | :---: |
| 0xA5 | 1B | 1B | 0~252B | 1B |

- **Payload**: `CMD_WRITE` — Address (4B) + Data (nB), little-endian.
- **Checksum**: Sum of all bytes (START through last PAYLOAD byte), truncated to 8 bits.

**TX Packet (FPGA → Host)**

| START | RES | LEN | PAYLOAD | CHECKSUM |
| :---: | :---: | :---: | :---: | :---: |
| 0xA5 | 1B | 1B | 0~1B | 1B |

#### 3. Commands (CMD)

| Command | Code | Description | Payload |
|:---:|:---:|:---|:---|
| **CMD_RESET** | 0x01 | Halt and reset CPU | None |
| **CMD_WRITE** | 0x02 | Write to memory | Addr(4B) + Data |
| **CMD_RUN**   | 0x03 | Start execution | None |
| **CMD_INPUT** | 0x04 | Send stdin data to CPU RX FIFO | Data (nB) |

#### 4. Responses (RES)

| Response | Code | LEN | Payload | Description |
|:---:|:---:|:---:|:---|:---|
| **RES_ACK**      | 0x06 | 0 | None | Command acknowledged |
| **RES_NAK**      | 0x15 | 0 | None | Command rejected |
| **RES_BOOT**     | 0x80 | 0 | None | CPU started (sent once on `CMD_RUN`) |
| **RES_EXIT**     | 0x81 | 1 | Exit code (1B) | Program exited via `_exit()` |
| **RES_PRINT**    | 0x82 | 1 | Character (1B) | MMIO character output |
| **RES_OVERFLOW** | 0x83 | 1 | Drop count (1B) | TX FIFO overflow: N output events were dropped (max 255) |

#### 5. Boot Sequence
1. Host sends `CMD_RUN`. The programmer automatically issues `CMD_RESET` first.
2. CPU begins execution and immediately sends `RES_BOOT` (hardware-generated via `boot_flag`).
3. Host enters CPU Console; keyboard input becomes active (line-buffered, sent as `CMD_INPUT`).
4. User program output follows as `RES_PRINT` packets; `getchar()`/`scanf()` in the program poll `MMIO_INPUT_ADDR`.
5. On `_exit(code)`, CPU sends `RES_EXIT` with the exit code. Console exits.

> **Note**: If `PRINT_FIFO` overflows, existing entries are preserved and transmitted first. Dropped entries are counted and reported as `RES_OVERFLOW` after the FIFO drains. Console exits on receiving `RES_OVERFLOW`.

## Software & Tools

> **Note**: The programmer tool is **Windows-specific** due to Win32 API usage (`CreateFileA`, `ReadFile`, `WriteFile`, etc.).

### Directory Structure
```
Software/
├── runtime/        # Common bare-metal runtime (shared by all apps)
│   ├── crt0.S          # Startup code: sp init, data copy, BSS clear, main call, trap handler
│   ├── linker.ld       # Linker script: ROM @ 0x0, RAM @ 0x20000, stack @ 0x40000
│   ├── syscalls.c      # MMIO syscalls: putchar, printf, sprintf, _exit, memcpy, etc.
│   └── common.mk       # Shared Makefile rules (compile, link, hex generation)
├── apps/           # Application source code
│   ├── firmware/       # Custom test firmware
│   ├── coremark/       # CoreMark benchmark
│   ├── dhrystone/      # Dhrystone benchmark
│   └── riscv-tests/    # Official RISC-V test suite (submodule)
├── build/          # Compiled output (per-app subdirectories)
│   ├── firmware/       # firmware.hex, firmware.elf, *.o
│   ├── coremark/       # coremark.hex, coremark.elf, *.o
│   ├── dhrystone/      # dhrystone.hex, dhrystone.elf, *.o
│   └── riscv-tests/    # add.hex, lw.hex, mul.hex, ...
└── programmer/     # Host-side UART programming tool (Windows)
```

### Toolchain Requirements
- **Compiler**: `riscv-none-elf-gcc`
- **Architecture**: `rv32im_zicsr_zifencei`
- **ABI**: `ilp32`
- **Compiler Flags**: `-O2 -nostdlib -nostartfiles -ffreestanding`

---

### `runtime/` — Common Bare-Metal Runtime

Shared startup and syscall code used by all applications.

| File | Description |
|------|-------------|
| `crt0.S` | Startup code: initializes `sp`, copies `.data` from ROM to RAM, clears `.bss`, installs trap handler, calls `main` then `_exit` |
| `linker.ld` | Linker script: ROM @ `0x00000000`, RAM @ `0x00020000`, stack top @ `0x00040000` |
| `syscalls.c` | Bare-metal syscall and standard library implementation (MMIO-based I/O, string utilities, timer functions) |
| `common.mk` | Shared build rules: compile `.c`/`.S`, link `.elf`, generate `.hex` via `objcopy` |

#### Supported Functions

**I/O**

| Function | Signature | Description |
|----------|-----------|-------------|
| `getchar` | `int getchar(void)` | Polls `MMIO_INPUT_ADDR` until a byte is available, returns it as `int` |
| `putchar` | `int putchar(int c)` | Writes a character to `MMIO_PRINT_ADDR` (UART TX) |
| `printf` | `int printf(const char *fmt, ...)` | Formatted output to UART TX; supports `%c`, `%s`, `%d`, `%i`, `%u`, `%x`, `%o`, `%p`, `%f`, `%l*`, `%*` (width from arg), width, `0`/`-` padding |
| `vprintf` | `int vprintf(const char *fmt, va_list ap)` | `va_list` variant of `printf`; used internally by `ee_printf` in CoreMark |
| `sprintf` | `int sprintf(char *str, const char *fmt, ...)` | Formatted output into a string buffer; same specifiers as `printf` |
| `scanf` | `int scanf(const char *fmt, ...)` | Reads input via `getchar()`; supports `%c`, `%s`, `%d`, `%i`, `%u`, `%x`, width for `%s`; skips whitespace before numeric/string fields |
| `_exit` | `void _exit(int code)` | Writes `0x100 | (code & 0xFF)` to `MMIO_PRINT_ADDR` (triggers `RES_EXIT`), then loops forever |

**String & Memory**

| Function | Signature | Description |
|----------|-----------|-------------|
| `memcpy` | `void *memcpy(void *dest, const void *src, size_t len)` | Copies `len` bytes from `src` to `dest` |
| `memset` | `void *memset(void *dest, int byte, size_t len)` | Fills `len` bytes of `dest` with `byte` |
| `strlen` | `size_t strlen(const char *s)` | Returns the length of string `s` |
| `strcmp` | `int strcmp(const char *s1, const char *s2)` | Lexicographic comparison of `s1` and `s2` |
| `strcpy` | `char *strcpy(char *dest, const char *src)` | Copies string `src` into `dest` |

**Timer**

| Function | Signature | Description |
|----------|-----------|-------------|
| `get_cycle` | `uint64_t get_cycle(void)` | Returns the 64-bit `mcycle` counter value |
| `time_us` | `uint32_t time_us(void)` | Returns elapsed microseconds based on `mcycle` (100 MHz) |
| `time_ms` | `uint32_t time_ms(void)` | Returns elapsed milliseconds based on `mcycle` (100 MHz) |

---

### `apps/firmware/` — Custom Test Firmware

A bare-metal test program written in C.

#### Files
| File | Description |
|------|-------------|
| `main.c` | User Program |
| `Makefile` | Sets `APP_NAME`, `APP_SRCS`, includes `../../runtime/common.mk` |

#### Build
```bash
cd Software/apps/firmware
make clean && make
```

---

### `apps/coremark/` — CoreMark Benchmark

Runs the [EEMBC CoreMark](https://github.com/eembc/coremark) benchmark (v1.0) on bare-metal RISC-V.

#### Files
| File | Description |
|------|-------------|
| `core_portme.h` | Platform configuration: `HAS_FLOAT=1`, 64-bit cycle counter (`rdcycle`/`rdcycleh`), `MEM_STATIC` |
| `core_portme.c` | Timing (`start_time`/`stop_time`/`get_time`/`time_in_secs`), seed variables, `ee_printf` via `vprintf` |
| `Makefile` | Sets `APP_NAME`, `APP_SRCS`, `ITERATIONS=3000`, `-DPERFORMANCE_RUN=1` |

#### Build
```bash
cd Software/apps/coremark
make clean && make
```

> CoreMark requires ≥ 10 seconds of continuous execution for a valid result. At 263.7 CoreMark/s, `ITERATIONS=3000` gives ~11.4 seconds.

---

### `apps/dhrystone/` — Dhrystone Benchmark

Runs the classic Dhrystone 2.2 synthetic integer benchmark.

#### Files
| File | Description |
|------|-------------|
| `dhrystone.h` | Merged header: `HZ=100000000`, `CLOCK_TYPE="mcycle"`, `NUMBER_OF_RUNS=10` for simulation sanity runs; `Start_Timer`/`Stop_Timer` use `mcycle` CSR |
| `dhrystone.c` | Dhrystone auxiliary procedures (Proc_6~8, Func_1~3) |
| `dhrystone_main.c` | Dhrystone main benchmark loop and result output |
| `util.h` | Benchmark utilities: `setStats` declaration, `encoding.h` include guard |
| `encoding.h` | CSR access macros: `read_csr`, `write_csr` |
| `Makefile` | Sets `APP_NAME`, `APP_SRCS`, `EXTRA_CFLAGS`, includes `../../runtime/common.mk` |

#### Timer Mechanism
Dhrystone timing uses the `mcycle` hardware counter (100 MHz):
```c
Start_Timer()  →  Begin_Time = (long)read_csr(mcycle);
Stop_Timer()   →  End_Time   = (long)read_csr(mcycle);
```

#### Build
```bash
cd Software/apps/dhrystone
make clean && make
```

---

### `apps/riscv-tests/` — Official RISC-V Test Suite

RISC-V ISA compliance tests (git submodule).

#### Build
```bash
cd Software/apps/riscv-tests
make TEST=add run

# Build all tests
make all-hex
# Output: Software/build/riscv-tests/*.hex
```

---

### `programmer/` — Host-Side UART Programming Tool

A Windows-only interactive command-line tool that communicates with the FPGA over UART.

#### Files
| File | Description |
|------|-------------|
| `programmer.c` | COM port setup, menu-driven command dispatch (RESET/BUILD/WRITE/RUN), `make` build integration, `.hex` parsing and chunked ROM upload via `CMD_WRITE`. `RUN` automatically issues `CMD_RESET` first to flush FIFOs. |
| `programmer.h` | Constants (`CHUNK_SIZE=62`), command enum (`CMD_RESET/WRITE/RUN/INPUT`) |
| `serial_port.c` | Win32 serial port: open/close/read/write, frame receiver, CPU console; line-buffered keyboard input sent as `CMD_INPUT` after `RES_BOOT`; Ctrl+D exits; exits on `RES_EXIT` or `RES_OVERFLOW` |
| `serial_port.h` | Protocol constants (`START_FLAG=0xA5`, `TIMEOUT_MS=20000`), response enum (`RES_ACK/NAK/BOOT/EXIT/PRINT/OVERFLOW`) |

#### Menu
```
1. RESET    Reset System
2. BUILD    Build Program Image  (invokes make, optional immediate write)
3. WRITE    Write Program Image
4. RUN      Run Program & CPU Monitor
5. EXIT     End Program
```

On `BUILD`, after a successful make, the tool asks:
```
Write Program Now? (Y/N):
```
If `Y`, it immediately uploads the freshly built `.hex` without re-selecting the image.

#### Protocol Constants
| Constant | Value | Description |
|----------|-------|-------------|
| `START_FLAG` | `0xA5` | Packet start byte |
| `CHUNK_SIZE` | `62` | Max words per `CMD_WRITE` packet (payload = 4 + 62×4 = 252 bytes) |
| `TIMEOUT_MS` | `20000` | Per-field receive timeout (20 seconds) |

#### Serial Port Settings
| Parameter | Value |
|-----------|-------|
| Baud Rate | 115200 |
| Byte Size | 8 |
| Stop Bits | 1 |
| Parity | None |
| Read Interval Timeout | 50 ms |
| Read Total Timeout | 50 ms + 10 ms × bytes |
| Write Total Timeout | 50 ms + 10 ms × bytes |

#### Build
```bash
cd Software/programmer
gcc programmer.c serial_port.c -o programmer.exe
```

---

### Typical Workflow

```bash
cd Software/programmer
programmer.exe
```

1. Enter COM port number (e.g., `3` for `COM3`)
2. `RESET` — Halt CPU, flush TX/RX FIFOs
3. `BUILD` — Build selected app, then optionally write immediately
4. `WRITE` — Upload selected `.hex` to ROM
5. `RUN` — Auto-reset, start CPU, enter CPU Console (Ctrl+D to exit)

## Simulation

This project uses **Vivado Simulator (XSim)** for functional verification.

### CPU Testbench

The CPU testbench (`RTL/Testbench/cpu_testbench.sv`) prints program output and simulation events (`[BOOT]`, `[PASS]`, `[FAIL: exit=N]`, `[TIMEOUT]`) to the simulation log.

#### Vivado GUI

1.  Add `RTL/Testbench/cpu_testbench.sv` to the project as a **Simulation Source** and set `cpu_testbench` as the **Top Module**.
2.  Add `Simulation/waveform.wcfg` to the simulation sources for pre-configured signal views. Includes grouped signals for each pipeline stage (IF, ID, EX, MEM1, MEM2, WB) and debug interfaces.
3.  Run **Behavioral Simulation**.

#### Batch Script

Runs the full XSim flow (compile → elaborate → simulate) without opening Vivado GUI.

```bat
Simulation\simulate.bat [app]   # app defaults to firmware
```

Loads `Software/build/<app>/<app>.hex`. Logs are written to `xvlog.log`, `elaborate.log`, and `simulate.log`.

### UART Testbench

The UART testbench (`RTL/Testbench/uart_testbench.sv`) verifies the UART controller in isolation, covering command parsing, ROM write, input FIFO, MMIO frame output, overflow behavior, and frame checksums.

```bat
Simulation\uart_simulate.bat
```

## Directory Structure

- `RTL/`: Top-level FPGA module (`riscv_cpu_fpga.sv`)
  - `Core/`: SystemVerilog source code for the RISC-V CPU Core
  - `UART/`: Source code for the UART controller and PHY
  - `Testbench/`: Simulation testbench files
- `Simulation/`: Waveform configuration files for Vivado Simulator
- `Software/`: Firmware, benchmarks, and host programming tool
  - `runtime/`: Common bare-metal runtime (shared by all apps)
  - `apps/`: Application source code (firmware, coremark, dhrystone, riscv-tests)
  - `build/`: Compiled output per app
  - `programmer/`: Host-side UART programming tool (Windows)
- `Constraints/`: FPGA constraint files (.xdc)

## License

See `LICENSE` file for details.
