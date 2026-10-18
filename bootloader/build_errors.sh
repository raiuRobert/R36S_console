#!/bin/bash
# Rebuild U-Boot serially and show the first compiler errors (for debugging build failures).
cd ~/src/u-boot
export CROSS_COMPILE=arm-linux-gnueabihf-
make -j1 2>&1 | grep -E -B2 -A6 "error:|Error " | head -60
