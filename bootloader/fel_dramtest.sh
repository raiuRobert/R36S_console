#!/bin/bash
# DRAM test over FEL: run only the SPL (it initialises DRAM and returns to FEL), then write
# random data to several DRAM regions over USB, read it back and compare.
# Usage (root, WSL): bash fel_dramtest.sh <u-boot-sunxi-with-spl.bin>
set -uo pipefail
BIN=${1:?usage: fel_dramtest.sh u-boot-sunxi-with-spl.bin}
T=/tmp/dramtest
mkdir -p $T

timeout 5 sunxi-fel version || { echo "FEL not answering"; exit 1; }
echo "--- running SPL only (DRAM init) from $BIN"
timeout 60 sunxi-fel -v spl "$BIN" 2>&1 | grep -vE "MMU|cache|mapping|Stack|translation" || { echo "SPL step failed"; exit 1; }
timeout 5 sunxi-fel version || { echo "FEL lost after SPL"; exit 1; }

head -c 262144 /dev/urandom > $T/pattern.bin
fails=0
for addr in 0x40000000 0x42000000 0x48000000 0x4a000000 0x4f000000 0x50000000 0x58000000 0x5ff00000; do
    timeout 60 sunxi-fel write $addr $T/pattern.bin || { echo "$addr: write failed"; fails=$((fails+1)); continue; }
    timeout 60 sunxi-fel read $addr 262144 $T/back.bin || { echo "$addr: read failed"; fails=$((fails+1)); continue; }
    if cmp -s $T/pattern.bin $T/back.bin; then
        echo "$addr: OK"
    else
        n=$(cmp -l $T/pattern.bin $T/back.bin | wc -l)
        echo "$addr: MISMATCH in $n of 262144 bytes"
        fails=$((fails+1))
    fi
done
echo "DRAM test done, failures: $fails"
