#!/bin/bash
# Show the exact commands used to build the GA36 device tree.
cd ~/src/u-boot
export CROSS_COMPILE=arm-linux-gnueabihf-
rm -f arch/arm/dts/sun8i-a23-ga36mb.dtb arch/arm/dts/.sun8i-a23-ga36mb.dtb.*
make V=1 arch/arm/dts/sun8i-a23-ga36mb.dtb 2>&1 | grep -E "cpp|dtc|rror" | cut -c1-400 | head -8
