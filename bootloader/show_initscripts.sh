#!/bin/bash
# Print the goodluckOS boot scripts from a card image (WSL, root): bash show_initscripts.sh <image> [script...]
IMG=$1; shift
W=/tmp/glk; mkdir -p $W/root
mount -o ro,loop,offset=134217728 "$IMG" $W/root || exit 1
cd $W/root/etc/init.d
for f in "${@:-rcS S01resize-home S30usb-gadget S90backlight S99appd}"; do for g in $f; do echo "===== $g"; cat "$g"; done; done
cd /; umount $W/root
