OUTPUT_ARCH(riscv)
ENTRY(rvtest_entry_point)

MEMORY {
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 128K
    RAM (rw)  : ORIGIN = 0x00020000, LENGTH = 128K
}

SECTIONS {
    .text.init : {
        . = ALIGN(4);
        *(.text.init)
        . = ALIGN(4);
    } > ROM

    .text.rvtest : {
        . = ALIGN(4);
        *(.text.rvtest)
        *(.text.rvtest.*)
        . = ALIGN(4);
    } > ROM

    .rodata : {
        . = ALIGN(4);
        *(.rodata*)
        *(.srodata*)
        *(.eh_frame*)
        . = ALIGN(4);
    } > ROM

    .text.rvmodel : {
        . = ALIGN(4);
        *(.text.rvmodel)
        *(.text.rvmodel.*)
        *(.text)
        *(.text.*)
        . = ALIGN(4);
    } > ROM

    .data : {
        . = ALIGN(4);
        _data_start = .;
        *(.data)
        *(.data.*)
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
    } > RAM

    _end = .;
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
