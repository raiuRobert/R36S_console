#!/bin/bash
# Print files from the goodluckOS rootfs of a card image (WSL, root): bash show_rootfs_files.sh <image> <path-in-rootfs>...
IMG=$1; shift
W=/tmp/glk; mkdir -p $W/root
mount -o ro,loop,offset=134217728 "$IMG" $W/root || exit 1
for p in "$@"; do echo "===== $p"; if [ -d "$W/root/$p" ]; then ls -la "$W/root/$p"; else cat "$W/root/$p"; fi; done
umount $W/root
