OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 128K
    DMEM (rw)  : ORIGIN = 0x00020000, LENGTH = 128K
}

SECTIONS {
    .text : {
        *(.text.init)
        *(.text*)
    } > IMEM

    .rodata : {
        *(.rodata*)
        *(.srodata*)
    } > DMEM

    .data : {
        *(.data*)
        *(.sdata*)
    } > DMEM

    .bss (NOLOAD) : {
        _bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        _bss_end = .;
        _end = .;
    } > DMEM

    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
