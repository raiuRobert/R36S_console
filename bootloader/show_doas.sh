#!/bin/bash
IMG=/mnt/d/dev/R36s_console/firmware/goodluckos/ga36_a23_panel2_falcon.img
W=/tmp/glk; mkdir -p $W/root
mount -o ro,loop,offset=134217728 "$IMG" $W/root || exit 1
ls -la $W/root/etc/doas.conf $W/root/etc/doas.d 2>&1; cat $W/root/etc/doas.conf $W/root/etc/doas.d/* 2>/dev/null
ls -la $W/root/usr/bin/doas
umount $W/root
