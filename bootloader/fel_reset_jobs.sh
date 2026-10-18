#!/bin/bash
# Stop any leftover FEL helper jobs, then check that the console answers in FEL mode.
for p in $(pgrep -f 'bootloader/(fel_diag|wait_fel_then|fel_boot)\.sh'); do
    [ "$p" != "$$" ] && kill "$p" 2>/dev/null
done
pkill -x sunxi-fel 2>/dev/null
sleep 1
lsusb | grep -i 1f3a
timeout 5 sunxi-fel version
echo "sunxi-fel version exit=$?"
