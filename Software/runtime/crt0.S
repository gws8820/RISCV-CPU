.section .text.init
.global _start

.section .text.trap
.align 2

putc_mmio:
    li   t0, 0xFFFF0000
    sw   a0, 0(t0)
    ret

puthex32:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    mv   s0, a0
    li   s1, 8
1:
    srli a0, s0, 28
    li   t0, 10
    bltu a0, t0, 2f
    addi a0, a0, 55
    j    3f
2:
    addi a0, a0, 48
3:
    call putc_mmio
    slli s0, s0, 4
    addi s1, s1, -1
    bnez s1, 1b

    lw   s1, 4(sp)
    lw   s0, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

trap_handler:
    addi sp, sp, -16
    sw   ra, 12(sp)

    li   a0, '['
    call putc_mmio
    li   a0, 'T'
    call putc_mmio
    li   a0, 'R'
    call putc_mmio
    li   a0, 'A'
    call putc_mmio
    li   a0, 'P'
    call putc_mmio
    li   a0, ']'
    call putc_mmio
    li   a0, ' '
    call putc_mmio
    li   a0, 'P'
    call putc_mmio
    li   a0, 'C'
    call putc_mmio
    li   a0, '='
    call putc_mmio

    csrr a0, mepc
    call puthex32
    li   a0, ' '
    call putc_mmio
    li   a0, 'C'
    call putc_mmio
    li   a0, 'A'
    call putc_mmio
    li   a0, 'U'
    call putc_mmio
    li   a0, 'S'
    call putc_mmio
    li   a0, 'E'
    call putc_mmio
    li   a0, '='
    call putc_mmio

    csrr a0, mcause
    call puthex32
    li   a0, ' '
    call putc_mmio
    li   a0, 'T'
    call putc_mmio
    li   a0, 'V'
    call putc_mmio
    li   a0, 'A'
    call putc_mmio
    li   a0, 'L'
    call putc_mmio
    li   a0, '='
    call putc_mmio

    csrr a0, mtval
    call puthex32
    li   a0, '\n'
    call putc_mmio

1:
    j    1b

.section .text.init
.align 2
_start:
    la   sp, _stack_top

    la   t0, _data_load_start
    la   t1, _data_start
    la   t2, _data_end
1:
    bge  t1, t2, 2f
    lw   t3, 0(t0)
    sw   t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j    1b
2:
    la   t0, _bss_start
    la   t1, _bss_end
3:
    bge  t0, t1, 4f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    3b
4:
    la   t0, trap_handler
    csrw mtvec, t0
    call main
    call _exit
5:
    j    5b
