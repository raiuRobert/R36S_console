#!/bin/bash
# With the SD card reader attached to WSL by usbipd: find the card (31,281,119,232 bytes), mount its
# goodluckOS rootfs (partition 1), install the root boot hook (install_root_hook.sh), unmount.
# Run in WSL as root.
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
modprobe usb-storage
DEV=""
for i in $(seq 1 30); do
    for b in /sys/block/sd*; do
        [ -e "$b/size" ] || continue
        [ "$(( $(cat "$b/size") * 512 ))" = 31281119232 ] && DEV=/dev/${b##*/}
    done
    [ -n "$DEV" ] && [ -e "${DEV}1" ] && break
    sleep 1
done
[ -n "$DEV" ] || { echo "card not found in WSL"; lsblk; exit 1; }
echo "card is $DEV"; lsblk -o NAME,SIZE,FSTYPE,LABEL "$DEV"
M=/mnt/ga36root; mkdir -p $M
mount -t ext4 "${DEV}1" $M || { echo "mount failed"; exit 1; }
bash "$HERE/install_root_hook.sh" $M; rc=$?
umount $M && echo "unmounted" ; sync
exit $rc
