#!/bin/bash
# Boot our U-Boot on the console over USB FEL (no SD card involved).
# Run as root inside WSL after `usbipd attach --wsl --busid <id>` on Windows.
# Usage: bash fel_boot.sh [u-boot-sunxi-with-spl.bin]
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=${1:-$HERE/out/u-boot-sunxi-with-spl.bin}

if ! lsusb -d 1f3a:efe8 >/dev/null; then
    echo "No FEL device (1f3a:efe8) visible in WSL. Attach it with usbipd first."
    exit 1
fi
sunxi-fel version
echo "--- loading $BIN over FEL (SPL -> DRAM init -> U-Boot)"
timeout 60 sunxi-fel -v -p uboot "$BIN"
echo "sunxi-fel exit code: $?"
sleep 2
echo "--- USB devices now:"
lsusb
