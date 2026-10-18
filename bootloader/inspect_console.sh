#!/bin/bash
# Check which UART the A23/Q8 device tree uses as console, and whether U-Boot supports the
# clocks/pins it needs.
cd ~/src/u-boot
echo "=== chosen/aliases in the Q8 + A23 trees ==="
grep -n -A4 "chosen\|aliases" arch/arm/dts/sun8i-q8-common.dtsi arch/arm/dts/sun8i-reference-design-tablet.dtsi 2>/dev/null | grep -E "serial|stdout|chosen|aliases" | head
echo "=== r-ccu / ccu compatibles supported by U-Boot clock drivers ==="
grep -rn "sun8i-a23-r-ccu\|sun8i-a23-ccu\|sun8i-a33-ccu" drivers/clk/sunxi/ | head
echo "=== r_uart / uart2 nodes in sun8i-a23-a33.dtsi ==="
grep -n -B1 -A8 "r_uart: serial@\|uart2: serial@" arch/arm/dts/sun8i-a23-a33.dtsi | grep -E "serial@|compatible|clocks|resets|status|pinctrl" | head -20
echo "=== uart2 pin groups ==="
grep -n -A3 "uart2.*pins: \|uart2_pb_pins\|uart2-pb" arch/arm/dts/sun8i-a23-a33.dtsi | head
echo "=== Sinlinx A33 console (worked) ==="
grep -n -A3 "chosen\|aliases" arch/arm/dts/sun8i-a33-sinlinx-sina33.dts | head -8
echo "=== sunxi-u-boot.dtsi console hints ==="
grep -n "stdout\|bootph\|uart" arch/arm/dts/sunxi-u-boot.dtsi | head
