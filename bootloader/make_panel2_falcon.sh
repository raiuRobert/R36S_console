#!/bin/bash
# Rebuild the panel-2 falcon card image from the panel-2 log image (WSL, root).
set -euo pipefail
G=/mnt/d/dev/R36s_console/firmware/goodluckos
B=/mnt/d/dev/R36s_console/bootloader
bash $B/make_falcon_image.sh $G/ga36_a23_panel2_log.img $B/out/u-boot-a23-falcon-log.bin $G/ga36_a23_panel2_falcon.img
bash $B/dtb_usb_nodes.sh /tmp/glk_falcon/dtb | tail -3
fdtget -t i /tmp/glk_falcon/dtb /soc/dsi@1ca0000/panel@0 panel-id
cp /tmp/glk_falcon/zImage_dtb $B/out/goodluck_a23_panel2_zImage_dtb.bin
cp /tmp/glk_falcon/dtb $B/out/goodluck_a23_panel2.dtb
