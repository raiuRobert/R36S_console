#!/bin/bash
# Compare the A23 device tree's USB OTG / PHY compatibles with what U-Boot's drivers match.
cd ~/src/u-boot
echo "=== compatibles in sun8i-a23.dtsi ==="
grep -n -B1 -A3 "&usb_otg\|&usbphy" arch/arm/dts/sun8i-a23.dtsi | grep -E "compatible|&usb"
echo "=== sunxi musb driver match table ==="
grep -n "compatible = " drivers/usb/musb-new/sunxi.c
echo "=== sun4i usb phy match table ==="
grep -n "compatible = " drivers/phy/allwinner/phy-sun4i-usb.c
echo "=== built objects ==="
ls drivers/usb/musb-new/*.o drivers/phy/allwinner/*.o drivers/usb/gadget/*.o 2>/dev/null | xargs -n1 basename | tr '\n' ' '
echo
