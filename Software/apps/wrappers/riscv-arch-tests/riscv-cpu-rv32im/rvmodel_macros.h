#ifndef RISCV_CPU_RVMODEL_MACROS_H
#define RISCV_CPU_RVMODEL_MACROS_H

#define RVMODEL_DATA_SECTION

#define RVMODEL_BOOT_TO_MMODE                                              \
    la t0, _data_load_start;                                               \
    la t1, _data_start;                                                    \
    la t2, _data_end;                                                      \
1:  bgeu t1, t2, 2f;                                                       \
    lw t3, 0(t0);                                                          \
    sw t3, 0(t1);                                                          \
    addi t0, t0, 4;                                                        \
    addi t1, t1, 4;                                                        \
    j 1b;                                                                  \
2:  la t0, _bss_start;                                                     \
    la t1, _bss_end;                                                       \
3:  bgeu t0, t1, 4f;                                                       \
    sw zero, 0(t0);                                                        \
    addi t0, t0, 4;                                                        \
    j 3b;                                                                  \
4:

#define RVMODEL_BOOT                                                       \
    la sp, _stack_top;

#define RVMODEL_IO_INIT(_R1, _R2, _R3)

#define RVMODEL_MMIO_PRINT_ADDR 0xFFFF0000

#define RVMODEL_IO_WRITE_STR(_R1, _R2, _R3, _STR_PTR)                      \
1:  lbu _R1, 0(_STR_PTR);                                                  \
    beqz _R1, 2f;                                                          \
    li _R2, RVMODEL_MMIO_PRINT_ADDR;                                       \
    sw _R1, 0(_R2);                                                        \
    addi _STR_PTR, _STR_PTR, 1;                                            \
    j 1b;                                                                  \
2:

#ifdef SIGNATURE

#define RVMODEL_HALT_PASS                                                  \
    .option push;                                                          \
    .option norvc;                                                         \
    li a1, 0x20026;                                                        \
    li a0, 0x18;                                                           \
    .balign 16;                                                            \
    slli x0, x0, 0x1f;                                                     \
    ebreak;                                                                \
    srai x0, x0, 7;                                                        \
    .option pop

#define RVMODEL_HALT_FAIL                                                  \
    .option push;                                                          \
    .option norvc;                                                         \
    li a1, 0x20023;                                                        \
    li a0, 0x18;                                                           \
    .balign 16;                                                            \
    slli x0, x0, 0x1f;                                                     \
    ebreak;                                                                \
    srai x0, x0, 7;                                                        \
    .option pop

#else

#define RVMODEL_HALT_PASS                                                  \
    li t0, RVMODEL_MMIO_PRINT_ADDR;                                        \
    li t1, 0x100;                                                          \
    sw t1, 0(t0);                                                          \
1:  j 1b

#define RVMODEL_HALT_FAIL                                                  \
    li t0, RVMODEL_MMIO_PRINT_ADDR;                                        \
    li t1, 0x101;                                                          \
    sw t1, 0(t0);                                                          \
1:  j 1b

#endif

#define RVMODEL_ACCESS_FAULT_ADDRESS 0x00000000
#define RVMODEL_INTERRUPT_LATENCY 10
#define RVMODEL_TIMER_INT_SOON_DELAY 100

#define RVMODEL_SET_MEXT_INT(_R1, _R2)
#define RVMODEL_CLR_MEXT_INT(_R1, _R2)
#define RVMODEL_SET_MSW_INT(_R1, _R2)
#define RVMODEL_CLR_MSW_INT(_R1, _R2)
#define RVMODEL_SET_SEXT_INT(_R1, _R2)
#define RVMODEL_CLR_SEXT_INT(_R1, _R2)
#define RVMODEL_SET_SSW_INT(_R1, _R2)
#define RVMODEL_CLR_SSW_INT(_R1, _R2)

#endif
