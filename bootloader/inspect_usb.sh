#!/bin/bash
# Show how U-Boot starts the ACM console and how the sunxi MUSB glue picks host/peripheral mode.
cd ~/src/u-boot
echo "=== f_acm.c: stdio start ==="
grep -n -A25 "static int acm_stdio_start" drivers/usb/gadget/f_acm.c | head -40
echo "=== sunxi musb: probe / mode selection ==="
grep -n -E "dr_mode|USB_DR_MODE|MUSB_HOST|MUSB_PERIPHERAL|usb_gadget|gadget|vbus|id_det|static int musb_usb_probe" drivers/usb/musb-new/sunxi.c | head -40
echo "=== Kconfig for MUSB gadget/host on sunxi ==="
grep -n -B2 -A8 "config USB_MUSB_GADGET" drivers/usb/musb-new/Kconfig | head -24
