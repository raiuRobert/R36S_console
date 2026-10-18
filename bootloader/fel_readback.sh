#!/bin/bash
# Read the U-Boot console log from on-chip SRAM A2 (0x44000) over FEL. Works right after a reset
# into FEL or after U-Boot jumped back to FEL; no DRAM init is needed.
# Usage (root, WSL): bash fel_readback.sh
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=$HERE/../logs/ramlog_$(date +%H%M%S).txt
BASE=0x44000

timeout 5 sunxi-fel version || { echo "FEL not answering"; exit 1; }
timeout 30 sunxi-fel read $BASE 0x10 /tmp/ramlog_hdr.bin || { echo "header read failed"; exit 1; }
magic=$(xxd -p -l4 /tmp/ramlog_hdr.bin)
len=$(od -An -t u4 -j4 -N4 /tmp/ramlog_hdr.bin | tr -d ' ')
echo "log magic=$magic length=$len"
if [ "$magic" != "524c4f47" ]; then
    echo "No log header in SRAM: U-Boot proper never printed anything (or SRAM was cleared)."
    exit 2
fi
[ "$len" -gt 0 ] && [ "$len" -le 16368 ] || { echo "bad length"; exit 1; }
timeout 60 sunxi-fel read $((BASE + 16)) "$len" "$OUT"
echo "=== log saved to $OUT ==="
cat "$OUT"
echo
