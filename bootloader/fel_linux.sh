#!/bin/bash
# Boot the goodluckOS A23 kernel over USB FEL, the way the falcon SPL does from the card:
# SPL (DRAM/PMIC init, returns to FEL) -> kernel payload (zImage + appended DTB) at 0x42000000
# -> DTB copy at 0x43000000 -> jump to 0x42000000. Nothing is written to the SD card.
# Linux mounts its root from the card in TF1 (/dev/mmcblk0p1), so: enter FEL with no card
# (RST), THEN insert the goodluckOS card, then run this. If Linux comes up, the console shows up
# on the PC as a USB serial device "goodluckOS GA36MB" (ACM gadget, getty on ttyGS0).
# Run in WSL as root: bash fel_linux.sh [u-boot-sunxi-with-spl.bin]
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SPL=${1:-$HERE/out/u-boot-a23-falcon-log.bin}
K=$HERE/out/goodluck_a23_zImage_dtb.bin
D=$HERE/out/goodluck_a23.dtb
LOG=$HERE/../logs/fel_linux.log
exec > >(tee -a "$LOG") 2>&1
echo "===== $(date '+%F %T') fel_linux $SPL ====="
[ -f $K ] && [ -f $D ] || { echo "run make_falcon_image.sh first (it extracts the kernel payload; copies are in bootloader/out)"; exit 1; }

timeout 5 sunxi-fel version || { echo "RESULT: FEL not answering (press RST with no card, re-attach usbipd)"; exit 1; }
timeout 60 sunxi-fel -p spl "$SPL" || { echo "RESULT: SPL failed"; exit 1; }
sleep 1
timeout 5 sunxi-fel version || { echo "RESULT: SPL did not return to FEL"; exit 1; }
echo "SPL done, DRAM up; uploading kernel ($(stat -c %s $K) bytes) ..."
timeout 300 sunxi-fel -p write 0x42000000 $K || { echo "RESULT: kernel upload failed"; exit 1; }
timeout 30 sunxi-fel write 0x43000000 $D || { echo "RESULT: DTB upload failed"; exit 1; }
echo "jumping to the kernel at $(date +%T)"
timeout 10 sunxi-fel exe 0x42000000
echo "RESULT: kernel started. Watch the screen; on the PC look for a new USB serial (COM) device."
