#!/bin/bash
# Boot the diagnostic U-Boot over FEL, wait for it to jump back to FEL, then read its RAM log.
# Run as root inside WSL with the console attached via usbipd (auto-attach).
# Usage: bash fel_diag.sh [u-boot-sunxi-with-spl.bin]
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=${1:-$HERE/out/u-boot-sunxi-with-spl.bin}
OUT=$HERE/../logs/ramlog_$(date +%H%M%S).txt

lsusb -d 1f3a:efe8 >/dev/null || { echo "No FEL device visible in WSL."; exit 1; }
sunxi-fel version
timeout 60 sunxi-fel -p uboot "$BIN" || { echo "FEL boot failed"; exit 1; }
echo "U-Boot started; waiting up to 60 s for it to return to FEL ..."
for i in $(seq 1 60); do
    sleep 1
    if timeout 3 sunxi-fel version >/dev/null 2>&1; then
        echo "back in FEL after ${i}s"
        timeout 60 sunxi-fel read 0x4f000000 0x10 /tmp/ramlog_hdr.bin || { echo "header read failed"; exit 1; }
        magic=$(xxd -p -l4 /tmp/ramlog_hdr.bin)
        len=$(od -An -t u4 -j4 -N4 /tmp/ramlog_hdr.bin | tr -d ' ')
        echo "ramlog magic=$magic length=$len"
        [ "$magic" = "524c4f47" ] || { echo "no RLOG magic: U-Boot never registered the ramlog"; exit 1; }
        [ "$len" -gt 0 ] && [ "$len" -lt 1048560 ] || { echo "bad length"; exit 1; }
        timeout 120 sunxi-fel read 0x4f000010 "$len" "$OUT"
        echo "=== log saved to $OUT ==="
        cat "$OUT"
        exit 0
    fi
done
echo "U-Boot did NOT return to FEL within 60 s (hung somewhere, or the FEL device isn't re-attached)."
exit 2
