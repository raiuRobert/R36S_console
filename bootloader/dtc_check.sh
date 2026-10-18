#!/bin/bash
# Compile the preprocessed GA36 device tree directly with dtc to see the real error message.
cd ~/src/u-boot/arch/arm/dts
dtc -I dts -O dtb -o /tmp/ga36.dtb .sun8i-a23-ga36mb.dtb.pre.tmp 2>&1 | head -20
