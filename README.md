# RISC-V CPU

A 6-stage pipelined RISC-V processor core designed for FPGA deployment, featuring an integrated UART controller for system programming and debugging.

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
  - **BHT (Branch History Table)**: 128 entries. Uses a 2-bit Saturating Counter (Strongly/Weakly Taken/Not Taken) to predict conditional branches.
  - **BTB (Branch Target Buffer)**: 128 entries. Stores Valid bit, Entry Type (Branch, Jump, Return), Tag, and Target Address.
  - **RAS (Return Address Stack)**: 32 entries. Predicts return addresses for `JALR` instructions marked as returns, supporting nested function calls.
  - **Performance**: No pipeline stalls or flushes on predicted branch hits.
- **Branch Resolution**:
  - **Branch Unit**: Resolution & validation in EX stage. Registers inputs for timing optimization (1-cycle latency).
  - **Recovery**: 3-cycle penalty on misprediction (Flush ID/EX/MEM, redirect PC)
- **Hazard Handling**:
  - RAW hazards resolved by forwarding from MEM1/MEM2/WB to EX
  - Store-Data hazards resolved by forwarding from WB to MEM1
  - Load-Use hazards resolved by pipeline stall
  - Branch Misprediction resolved by pipeline flush
- **Trap/Exception Support**:
  - ECALL, EBREAK, MRET
  - Illegal Instruction
  - Instruction/Data Address Misalign
  - Instruction/Data Access Fault
- **Hardware Multiplier & Divisor**:
  - **Multiplier**: Implemented using inferred DSP blocks (via synthesis attributes).
  - **Divisor**: Implemented using a custom iterative shift-subtract logic.

## Clock Domain and Reset

### Target FPGA
- **Board**: ALINX AX7Z020B (Zynq-7020)
- **Input Clock**: 50 MHz (onboard oscillator)
- **Internal Clock**: 120 MHz (via MMCM)

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

### Instruction Memory (IMEM)
- **Size**: 128KB (32768 words)
- **Width**: 32-bit
- **Access**: Runtime programmable via UART
- **Description**: Stores program code. Can be updated without FPGA reconfiguration.

### Data Memory (DMEM)
- **Size**: 256KB (65536 words)
- **Width**: 32-bit
- **Access**: Read/Write
- **IO Mapping**: Writes to `0xFFFF_0000` (PRINT_ADDR) are redirected to UART TX for debug output.

## Performance Characteristics

### Pipeline Performance
- **Ideal CPI**: 1.0
- **Actual CPI**: Depends on program characteristics (typically 1.1-1.5 due to hazards)

### Hazard Penalties
| Hazard Type | Penalty (Cycles) | Detection Stage | Notes |
|-------------|------------------|-----------------|-------|
| **Data Hazard (RAW)** | 0 | EX | Resolved by forwarding from MEM1/MEM2/WB stages |
| **Store-Data Hazard** | 0 | MEM1 | Resolved by forwarding from WB stage |
| **Load-Use Hazard** | 2 | ID | Detect on ID → use in EX (Forward from WB) |
| **Branch Prediction Hit** | 0 | IF | Zero penalty (Seamless execution) |
| **Branch Prediction Miss** | 3 | EX | Flush ID, EX, MEM1 stages, redirect PC |
| **Multiplication Stall** | 2 | EX | Pipeline stall during multiplication |
| **Division Stall** | 33 | EX | Pipeline stall during division |

### Trap/Exception Penalties
| Trap/Flush Type | Penalty (Cycles) | Processing Stage | Notes |
|-----------------|------------------|------------------|-------|
| **All Traps** | 3 | MEM1 | Flush all stages, redirect to mtvec |
| **MRET** | 3 | MEM1 | Flush all stages, restore PC from mepc |
| **FENCE.I** | 3 | MEM1 | Flush all stages, instruction memory sync |

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

The core implements the following Machine-mode CSRs:

| CSR Address | Name | Description |
|-------------|------|-------------|
| 0x300 | **mstatus** | Machine status register (MIE, MPIE bits) |
| 0x304 | **mie** | Machine interrupt-enable register |
| 0x305 | **mtvec** | Machine trap-handler base address (default: 0x40) |
| 0x340 | **mscratch** | Machine scratch register for trap handlers |
| 0x341 | **mepc** | Machine exception program counter |
| 0x342 | **mcause** | Machine trap cause |
| 0x343 | **mtval** | Machine trap value (bad address or instruction) |
| 0x344 | **mip** | Machine interrupt-pending register |
| 0xF14 | **mhartid** | Hardware thread ID (read-only, hart ID = 0) |

## UART Subsystem

Integrated UART controller for communication and system control.

- **System Programmer**: Loads compiled programs (`.hex`) into Instruction Memory.
- **Standard Output**: MMIO-based character output for debugging.

### Protocol Specification

#### 1. Configuration

| Parameter | Value |
|:---|:---|
| **Baud Rate** | 115200 bps |
| **Data Bits** | 8 bits |
| **Stop Bits** | 1 bit |
| **Parity** | None |
| **Oversampling** | 16x |

#### 2. Packet Structure

**RX Packet (Host → FPGA)**
```
[START: 0xA5] [CMD: 1B] [LEN: 1B] [PAYLOAD: 0~252B] [CHECKSUM: 1B]
```
- **Payload**: Address (4B) + Data (nB). All little-endian.

**TX Packet (FPGA → Host)**
```
[START: 0xA5] [RES: 1B] [LEN: 1B] [DATA: 0~4B] [CHECKSUM: 1B]
```

#### 3. Commands (CMD)

| Command | Code | Description | Payload |
|:---:|:---:|:---|:---|
| **CMD_RESET** | 0x01 | Halt and reset CPU | None |
| **CMD_WRITE** | 0x02 | Write to memory | Addr(4B) + Data |
| **CMD_RUN**   | 0x03 | Start execution | None |

#### 4. Responses (RES)

| Response | Code | Description | Data |
|:---:|:---:|:---|:---|
| **RES_ACK** | 0x06 | Command Success | None |
| **RES_NAK** | 0x15 | Command Failed | None |
| **RES_PRINT**| 0x80 | Async CPU Output | 4 Bytes |

## Software & Tools

> **Note**: The programmer tool is **Windows-specific** due to COM port handling.

### Compilation
The programmer tool requires MinGW or similar GCC environment:
```bash
cd Software
gcc cpu_programmer.c serial_port.c -o cpu_programmer.exe
```

### Usage
1.  **Program File**: Place `program.hex` in the root directory (`../program.hex` relative to Software)
2.  **Connect**: Connect FPGA board via USB.
3.  **Run**: `cpu_programmer.exe`
4.  **Sequence**: `RESET` -> `WRITE` -> `RUN`

## Simulation

### Vivado Simulator
This project relies on **Vivado Simulator (XSim)** for functional verification.

1.  **Setup**:
    - Add `RTL/Testbench/cpu_testbench.sv` to the project as a **Simulation Source**.
    - Set `cpu_testbench` as the **Top Module** in simulation settings.

2.  **Waveform**:
    - Add `Simulation/waveform.wcfg` to the simulation sources for pre-configured signal views.
    - This configuration includes grouped signals for each pipeline stage (IF, ID, EX, MEM, WB) and debug interfaces.

3.  **Execution**:
    - Run **Behavioral Simulation**.
    - The testbench initializes the CPU and executes a test sequence.

## Directory Structure

- `RTL/`: Top-level FPGA module (`riscv_cpu_fpga.sv`)
  - `Core/`: SystemVerilog source code for the RISC-V CPU Core
  - `UART/`: Source code for the UART controller and PHY
  - `Testbench/`: Simulation testbench files
- `Simulation/`: Waveform configuration files for Vivado Simulator
- `Software/`: C-based host programmer tool and libraries (Windows)
- `Constraints/`: FPGA constraint files (.xdc)

## License

See `LICENSE` file for details.

## Contributors

Developed as part of a RISC-V CPU design project.
