#!/bin/bash
# Locate the A23 device tree sources used by the U-Boot build and show their USB OTG nodes.
cd ~/src/u-boot
grep -E "^CONFIG_OF_UPSTREAM" .config || echo "OF_UPSTREAM not set"
find . -name 'sun8i-a23-q8-tablet.dts' -o -name 'sun8i-a23.dtsi' -o -name 'sun8i-a23-a33.dtsi' | grep -v '^./out'
echo "--- usb_otg / usbphy in the A23/A33 dtsi:"
f=$(find . -name 'sun8i-a23-a33.dtsi' | head -1)
grep -n -A8 "usb_otg: usb@" "$f" | head -14
grep -n -A6 "usbphy: phy@" "$f" | head -10
echo "--- boards enabling usb_otg:"
grep -l "&usb_otg" $(dirname "$f")/sun8i-a23*.dts $(dirname "$f")/sun8i-*q8*.dtsi 2>/dev/null
