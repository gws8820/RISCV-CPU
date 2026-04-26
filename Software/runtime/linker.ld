OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY {
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 128K
    RAM (rw)  : ORIGIN = 0x00020000, LENGTH = 128K
}

SECTIONS {
    .text : {
        . = ALIGN(4);
        *(.text.init)
        *(.text*)
        . = ALIGN(4);
    } > ROM

    .rodata : {
        . = ALIGN(4);
        *(.rodata*)
        *(.srodata*)
        *(.eh_frame*)
        . = ALIGN(4);
    } > ROM

    .data : {
        . = ALIGN(4);
        _data_start = .;
        *(.data*)
        *(.sdata*)
        . = ALIGN(4);
        _data_end = .;
    } > RAM AT > ROM
    _data_load_start = LOADADDR(.data);

    .bss (NOLOAD) : {
        . = ALIGN(4);
        _bss_start = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
        _end = .;
    } > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
