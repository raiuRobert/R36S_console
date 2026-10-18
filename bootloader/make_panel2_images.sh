#!/bin/bash
# Build the panel-2 variants of the log and falcon card images (WSL, root).
set -euo pipefail
G=/mnt/d/dev/R36s_console/firmware/goodluckos
B=/mnt/d/dev/R36s_console/bootloader
bash $B/make_log_image.sh $G/goodluck_base_a23_panel2.img $B/out/u-boot-a23-log.bin $G/ga36_a23_panel2_log.img
bash $B/make_falcon_image.sh $G/ga36_a23_panel2_log.img $B/out/u-boot-a23-falcon-log.bin $G/ga36_a23_panel2_falcon.img
dtc -I dtb -O dts /tmp/glk_falcon/dtb 2>/dev/null | grep -n "panel-id\|model ="
cp /tmp/glk_falcon/zImage_dtb $B/out/goodluck_a23_panel2_zImage_dtb.bin
cp /tmp/glk_falcon/dtb $B/out/goodluck_a23_panel2.dtb
