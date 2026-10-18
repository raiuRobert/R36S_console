#!/bin/bash
# Build the falcon-mode card image from the log image (which already has the S00ga36log script):
#   - u-boot-sunxi-with-spl.bin (falcon SPL + U-Boot proper log build as fallback) at 8 KiB
#   - legacy uImage of the goodluckOS kernel (zImage + appended DTB, as stored in the Android
#     boot image at sector 0x2a000) at sector 0x2000 (4 MiB)
#   - a copy of the appended DTB at sector 0x1000 (2 MiB) = falcon "args"
# Run in WSL as root: bash make_falcon_image.sh <log image> <u-boot-sunxi-with-spl.bin> <output image>
set -euo pipefail
SRC=${1:?usage}; UBOOT=${2:?usage}; OUT=${3:?usage}
MKIMAGE=/home/rober/src/u-boot/tools/mkimage
W=/tmp/glk_falcon; rm -rf $W; mkdir -p $W

cp --sparse=always "$SRC" "$OUT"

# Kernel payload = Android boot image kernel (header: kernel_size at offset 8, page size 2048)
dd if="$OUT" of=$W/bootimg_hdr bs=512 skip=$((0x2a000)) count=4 status=none
[ "$(head -c 8 $W/bootimg_hdr)" = "ANDROID!" ] || { echo "no Android boot image at 0x2a000"; exit 1; }
KSIZE=$(od -An -tu4 -j8 -N4 $W/bootimg_hdr | tr -d ' ')
dd if="$OUT" of=$W/zImage_dtb bs=512 skip=$((0x2a004)) count=$(( (KSIZE + 511) / 512 )) status=none
truncate -s "$KSIZE" $W/zImage_dtb
ZEND=$(od -An -tu4 -j44 -N4 $W/zImage_dtb | tr -d ' ')
dd if=$W/zImage_dtb of=$W/dtb bs=1 skip="$ZEND" status=none
echo "kernel payload $KSIZE bytes (zImage $ZEND + DTB $(stat -c %s $W/dtb)), DTB magic $(head -c 4 $W/dtb | xxd -p)"
[ "$(head -c 4 $W/dtb | xxd -p)" = d00dfeed ] || { echo "appended DTB not found"; exit 1; }

# DTB fixes for this board:
# - logs/boot1: the USB PHY's usb0_vbus-supply is the AXP223 drivevbus regulator, which Linux only
#   registers with x-powers,drive-vbus-en on the PMIC node, so the PHY deferred forever (no USB).
# - logs/boot2: adding x-powers,drive-vbus-en made USB work but the connection to the PC dropped
#   every 3-8 s (also with Windows' MTP driver disabled). That property turns an AXP pin of unknown
#   wiring into a VBUS-drive output, and dr_mode "otg" lets the ID pin switch roles. So instead:
#   USB device mode only (dr_mode "peripheral") and no VBUS regulator for the PHY at all.
fdtput -d $W/dtb /soc/phy@1c19400 usb0_vbus-supply
fdtput -t s $W/dtb /soc/usb@1c19000 dr_mode peripheral
! fdtget -p $W/dtb /soc/phy@1c19400 | grep -qx 'usb0_vbus-supply' &&
    [ "$(fdtget -t s $W/dtb /soc/usb@1c19000 dr_mode)" = peripheral ] || { echo "DTB fix failed"; exit 1; }
head -c "$ZEND" $W/zImage_dtb > $W/zImage
cat $W/zImage $W/dtb > $W/zImage_dtb
echo "DTB fixed (USB peripheral only, no VBUS regulator): payload now $(stat -c %s $W/zImage_dtb) bytes"

$MKIMAGE -A arm -O linux -T kernel -C none -a 0x42000000 -e 0x42000000 -n "goodluckOS A23 kernel" \
    -d $W/zImage_dtb $W/uImage | sed 's/^/  /'
[ "$(stat -c %s $W/dtb)" -le $((0x40 * 512)) ] || { echo "DTB larger than the args area"; exit 1; }

dd if="$UBOOT" of="$OUT" bs=1024 seek=8 conv=notrunc status=none
dd if=$W/dtb of="$OUT" bs=512 seek=$((0x1000)) conv=notrunc status=none
dd if=$W/uImage of="$OUT" bs=512 seek=$((0x2000)) conv=notrunc status=none

# Verify everything by reading it back
cmp -n "$(stat -c %s "$UBOOT")" "$UBOOT" <(dd if="$OUT" bs=1024 skip=8 status=none) && echo "U-Boot at 8 KiB: OK"
cmp -n "$(stat -c %s $W/dtb)" $W/dtb <(dd if="$OUT" bs=512 skip=$((0x1000)) status=none) && echo "DTB at sector 0x1000: OK"
cmp -n "$(stat -c %s $W/uImage)" $W/uImage <(dd if="$OUT" bs=512 skip=$((0x2000)) status=none) && echo "uImage at sector 0x2000: OK"
END=$(( 0x2000 * 512 + $(stat -c %s $W/uImage) ))
[ $END -lt $((84 << 20)) ] && echo "uImage ends at $END bytes, below the boot image at 84 MiB"
sha256sum "$OUT"
