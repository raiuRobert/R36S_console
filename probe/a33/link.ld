/* Runs from SRAM A1 (32 KiB at 0x0); keep the image well under 24 KiB. */
ENTRY(_start)
SECTIONS
{
    . = 0x0;
    .text : { *(.text.start) *(.text*) *(.rodata*) }
    .data : { *(.data*) }
    .bss  : { *(.bss*) *(COMMON) }
    /DISCARD/ : { *(.ARM.*) *(.comment) }
}
