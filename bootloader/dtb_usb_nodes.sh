#!/bin/bash
# Show the USB PHY / OTG controller nodes of a DTB: bash dtb_usb_nodes.sh <dtb>
D=${1:-/mnt/d/dev/R36s_console/bootloader/out/goodluck_a23.dtb}
fdtget -l "$D" /soc | grep -E '^(usb|phy)@'
echo "-- phy@1c19400:"; fdtget -p "$D" /soc/phy@1c19400
echo "-- usb@1c19000 dr_mode: $(fdtget -t s "$D" /soc/usb@1c19000 dr_mode)"
echo "-- pmic: $(fdtget -p "$D" /soc/rsb@1f03400/pmic@3a3 | tr '\n' ' ')"
