#!/bin/bash
# One interactive FEL debugging session, meant to run in a visible terminal:
#   1. wait for a fresh FEL device (asks the user to press RST)
#   2. boot the given U-Boot over FEL
#   3. if it returns to FEL by itself (go 0xffff0020): read its RAM log
#      otherwise: ask the user to press RST, then re-init DRAM and read the RAM log back
# Usage (root, WSL): bash fel_session.sh <u-boot-sunxi-with-spl.bin>
set -uo pipefail
BIN=${1:?usage: fel_session.sh u-boot-sunxi-with-spl.bin}
HERE=$(cd "$(dirname "$0")" && pwd)
LOG=$HERE/../logs/fel_session.log
exec > >(tee -a "$LOG") 2>&1
echo "===== $(date '+%F %T') fel_session $BIN ====="

fel_devnum() {
    lsusb -d 1f3a:efe8 2>/dev/null | awk '{print $4}' | tr -d ':'
}

# Wait for a FRESH FEL device: it must re-enumerate (new USB device number) after the reset,
# because a FEL session that has already run an SPL can't take another upload.
wait_fel() {
    local msg=$1 before
    before=$(fel_devnum)
    echo
    echo "##########################################################"
    echo "##  $msg"
    echo "##########################################################"
    for i in $(seq 1 300); do
        local now
        now=$(fel_devnum)
        if [ -n "$now" ] && [ "$now" != "$before" ] && timeout 3 sunxi-fel version >/dev/null 2>&1; then
            echo "FEL ready (USB device $now)."
            return 0
        fi
        [ -z "$now" ] && before=""
        sleep 2
    done
    echo "Gave up waiting for FEL."
    exit 3
}

# FEL_NOW=1: the console is already in a fresh FEL state (just reset, nothing uploaded yet).
if [ "${FEL_NOW:-}" = 1 ] && timeout 3 sunxi-fel version >/dev/null 2>&1; then
    echo "Using the FEL device that is already attached (FEL_NOW=1)."
else
    wait_fel "Press RST on the console now (no SD card, OTG cable connected)"
fi
sunxi-fel version
echo "--- booting U-Boot over FEL"
if ! timeout 60 sunxi-fel -p uboot "$BIN"; then
    echo "FEL upload failed."
    exit 1
fi
echo "U-Boot started."
echo ">>> WATCH THE SCREEN NOW: 5 quick backlight blinks = U-Boot proper is running <<<"
echo "Waiting up to 45 s for it to return to FEL by itself ..."
for i in $(seq 1 15); do
    sleep 3
    if timeout 3 sunxi-fel version >/dev/null 2>&1; then
        echo "U-Boot returned to FEL after ~$((i * 3)) s."
        exec bash "$HERE/fel_readback.sh"
    fi
done
echo "U-Boot did not return to FEL (it hung or crashed)."
wait_fel "Press RST on the console now, so the RAM log can be read back"
exec bash "$HERE/fel_readback.sh"
