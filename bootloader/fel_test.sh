#!/bin/bash
# Autonomous FEL test: boot U-Boot over FEL whose preboot writes a marker to DRAM and jumps back to
# the FEL boot ROM (go 0xffff0020); then check that FEL answers again and read the marker / log.
# Usage (root, WSL): bash fel_test.sh <u-boot-sunxi-with-spl.bin | u-boot.bin> [proper]
#   proper: DRAM is already initialised (previous test returned to FEL): load only U-Boot proper
#           to 0x4a000000 and execute it, skipping the SPL (running the SPL twice breaks FEL).
set -uo pipefail
BIN=${1:?usage}
MODE=${2:-}
HERE=$(cd "$(dirname "$0")" && pwd)
LOG=$HERE/../logs/fel_test.log
exec > >(tee -a "$LOG") 2>&1
echo "===== $(date '+%F %T') fel_test $BIN $MODE ====="

timeout 5 sunxi-fel version || { echo "RESULT: FEL not answering at start"; exit 1; }
# Never touch DRAM before the SPL has initialised it (in the default mode DRAM is not up yet).
if [ "$MODE" = proper ]; then
    printf '\0\0\0\0' > /tmp/zero4; timeout 30 sunxi-fel write 0x4f000000 /tmp/zero4
    timeout 120 sunxi-fel write 0x4a000000 "$BIN" && timeout 10 sunxi-fel exe 0x4a000000 \
        || { echo "RESULT: upload/exe failed"; exit 1; }
else
    timeout 120 sunxi-fel -p uboot "$BIN" || { echo "RESULT: FEL upload failed"; exit 1; }
fi
echo "U-Boot started at $(date +%T); waiting up to 40 s for it to return to FEL ..."
for i in $(seq 1 20); do
    sleep 2
    if timeout 3 sunxi-fel version >/dev/null 2>&1; then
        echo "RESULT: U-Boot returned to FEL after ~$((i * 2)) s"
        timeout 30 sunxi-fel read 0x4f000000 16 /tmp/marker.bin && xxd /tmp/marker.bin
        timeout 60 sunxi-fel read 0x4f100000 0x4000 /tmp/envdump.bin 2>/dev/null && \
            { echo "--- env/log area 0x4f100000:"; tr -c '[:print:]\n' '.' < /tmp/envdump.bin | tr -s '.' | head -c 4000; echo; }
        exit 0
    fi
done
echo "RESULT: U-Boot did NOT return to FEL within 40 s (hung, crashed, or go-to-FEL failed)"
exit 2
