#!/bin/bash
# Build the "log" card image: goodluckOS A23 + mainline U-Boot log build at 8 KiB + the
# S00ga36log boot-log script in the rootfs. Run in WSL as root:
#   bash make_log_image.sh <source image> <u-boot-sunxi-with-spl.bin> <output image>
set -euo pipefail
SRC=${1:?usage}; UBOOT=${2:?usage}; OUT=${3:?usage}
HERE=$(cd "$(dirname "$0")" && pwd)
W=/tmp/glk_log
mkdir -p $W/root

cp --sparse=always "$SRC" "$OUT"
dd if="$UBOOT" of="$OUT" bs=1024 seek=8 conv=notrunc status=none
cmp -n "$(stat -c %s "$UBOOT")" "$UBOOT" <(dd if="$OUT" bs=1024 skip=8 status=none) && echo "U-Boot written at 8 KiB and verified"

mountpoint -q $W/root && umount $W/root
mount -o loop,offset=134217728 "$OUT" $W/root
install -m 0755 "$HERE/rootfs/S00ga36log" $W/root/etc/init.d/S00ga36log
sed -i 's/\r$//' $W/root/etc/init.d/S00ga36log
ls -l $W/root/etc/init.d/S00ga36log
sh -n $W/root/etc/init.d/S00ga36log && echo "S00ga36log syntax OK"
sync
umount $W/root
LOOP=$(losetup -f --show -o 134217728 --sizelimit 402653184 "$OUT")
e2fsck -fn "$LOOP" | tail -2 || true
losetup -d "$LOOP"
sha256sum "$OUT"
