@ Allwinner eGON boot0 header + entry for the A33 sign-of-life probe.
@ The BROM loads this file from SD byte offset 8192 into SRAM A1 (0x0) and jumps to offset 0.
@ pack_egon.py fills in the checksum and length fields after linking.

    .section .text.start, "ax"
    .arm
    .global _start
_start:
    b       reset
    .ascii  "eGON.BT0"
    .word   0x5F0A6C39          @ checksum (stamp value, replaced by pack_egon.py)
    .word   0                   @ total length (replaced by pack_egon.py)
    .space  0x30 - 0x14         @ rest of the header, unused by the BROM

reset:
    ldr     sp, =0x7ff0         @ top of the 32 KiB SRAM A1
    bl      main
1:  b       1b
