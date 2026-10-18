#!/bin/bash
# Show how goodluckOS's appctl handles the autolaunch file (WSL, root).
IMG=/mnt/d/dev/R36s_console/firmware/goodluckos/ga36_a23_panel2_falcon.img
W=/tmp/glk; mkdir -p $W/root
mount -o ro,loop,offset=134217728 "$IMG" $W/root || exit 1
grep -n -i -A12 'autolaunch' $W/root/usr/local/bin/appctl | sed -n '1,80p'
echo "===== sysctl dmesg_restrict:"; grep -rs dmesg_restrict $W/root/etc/sysctl* $W/root/etc/sysctl.d 2>/dev/null
echo "===== player groups:"; grep player $W/root/etc/group
umount $W/root
