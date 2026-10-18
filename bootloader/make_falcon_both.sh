#!/bin/bash
# Rebuild both falcon card images (panel 1 and 2) from the log images (WSL, root).
set -euo pipefail
G=/mnt/d/dev/R36s_console/firmware/goodluckos
B=/mnt/d/dev/R36s_console/bootloader
for p in 1 2; do
    echo "===== panel $p"
    bash $B/make_falcon_image.sh $G/ga36_a23_panel${p}_log.img $B/out/u-boot-a23-falcon-log.bin $G/ga36_a23_panel${p}_falcon.img
    dtc -I dtb -O dts /tmp/glk_falcon/dtb 2>/dev/null | grep -E "panel-id|drive-vbus"
    cp /tmp/glk_falcon/zImage_dtb $B/out/goodluck_a23_panel${p}_zImage_dtb.bin
    cp /tmp/glk_falcon/dtb $B/out/goodluck_a23_panel${p}.dtb
done
