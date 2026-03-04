OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 128K
    DMEM (rw)  : ORIGIN = 0x00000000, LENGTH = 256K
}

SECTIONS {
    .text : {
        *(.text.init)
        *(.text*)
    } > IMEM

    .bss (NOLOAD) : {
        _bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > DMEM

    .data : {
        *(.data*)
        *(.sdata*)
    } > DMEM

    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
