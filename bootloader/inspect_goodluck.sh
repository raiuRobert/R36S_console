#!/bin/bash
# Look inside the goodluckOS A23 card image: kernel config (from the zImage), forced cmdline, the
# rootfs init system and where the FAT HOME partition gets mounted.
# Run (WSL, root): bash inspect_goodluck.sh <image>
set -uo pipefail
IMG=${1:?usage: inspect_goodluck.sh <image>}
W=/tmp/glk
mkdir -p $W/root
# zImage = Android boot image at sector 172032 + 2048-byte header page
dd if="$IMG" of=$W/zImage bs=512 skip=$((172032 + 4)) count=$((0x4000)) status=none
python3 - "$W/zImage" "$W" <<'EOF'
import sys, gzip, lzma, zlib, struct, os
z = open(sys.argv[1], 'rb').read()
w = sys.argv[2]
print("zImage magic", hex(struct.unpack_from('<I', z, 0x24)[0]), "start", hex(struct.unpack_from('<I', z, 0x28)[0]), "end", hex(struct.unpack_from('<I', z, 0x2c)[0]))
end = struct.unpack_from('<I', z, 0x2c)[0]
print("appended DTB magic at end:", z[end:end+4].hex())
kern = None
for name, magic in (('gzip', b'\x1f\x8b\x08'), ('xz', b'\xfd7zXZ\x00'), ('lzma', b'\x5d\x00\x00')):
    i = z.find(magic)
    while i >= 0 and kern is None:
        try:
            if name == 'gzip':
                kern = zlib.decompressobj(31).decompress(z[i:])
            else:
                kern = lzma.LZMADecompressor().decompress(z[i:])
            print("kernel compression", name, "at", hex(i), "->", len(kern), "bytes")
        except Exception:
            kern = None
            i = z.find(magic, i + 1)
    if kern:
        break
if not kern:
    lz4 = z.find(b'\x02\x21\x4c\x18')
    print("no gzip/xz kernel found; lz4 legacy magic at", hex(lz4) if lz4 >= 0 else None)
    sys.exit(0)
open(w + '/Image', 'wb').write(kern)
i = kern.find(b'IKCFG_ST')
if i >= 0:
    cfg = zlib.decompressobj(31).decompress(kern[i + 8:])
    open(w + '/config', 'wb').write(cfg)
    print("kernel config extracted:", len(cfg), "bytes")
else:
    print("no IKCONFIG in kernel")
for s in (b'root=/dev/mmcblk', b'Linux version '):
    j = kern.find(s)
    if j >= 0:
        print(repr(kern[j:kern.find(b'\0', j)][:300]))
EOF
if [ -f $W/config ]; then
    grep -E '^(CONFIG_CMDLINE|CONFIG_CMDLINE_FORCE|CONFIG_ARM_APPENDED_DTB|CONFIG_ARM_ATAG_DTB_COMPAT|CONFIG_FRAMEBUFFER_CONSOLE|CONFIG_VT|CONFIG_VT_CONSOLE|CONFIG_DRM_SUN4I|CONFIG_DRM_SUN6I_DSI|CONFIG_USB_MUSB_HDRC|CONFIG_USB_MUSB_SUNXI|CONFIG_USB_MUSB_DUAL_ROLE|CONFIG_USB_MUSB_HOST|CONFIG_USB_HID|CONFIG_HID_GENERIC|CONFIG_USB_EHCI_HCD|CONFIG_PSTORE|CONFIG_PSTORE_RAM|CONFIG_PANIC_TIMEOUT|CONFIG_SUNXI_WATCHDOG|CONFIG_LOG_BUF_SHIFT|CONFIG_MMC_SUNXI|CONFIG_EXT4_FS|CONFIG_VFAT_FS|CONFIG_MFD_AXP20X_RSB|CONFIG_SUNXI_RSB|CONFIG_ARM_PSCI|CONFIG_SMP|CONFIG_DRM_PANEL.*)=' $W/config
    grep -E '^# CONFIG_(FRAMEBUFFER_CONSOLE|VT|ARM_APPENDED_DTB|USB_HID|USB_MUSB_HDRC) is not set' $W/config
fi

echo "----- rootfs"
mountpoint -q $W/root && umount $W/root
mount -o ro,loop,offset=134217728 "$IMG" $W/root || { echo "mount failed"; exit 1; }
ls $W/root
cat $W/root/etc/os-release 2>/dev/null | head -5
ls -la $W/root/sbin/init 2>/dev/null
echo "--- fstab"; cat $W/root/etc/fstab 2>/dev/null
echo "--- inittab"; head -40 $W/root/etc/inittab 2>/dev/null
echo "--- init.d"; ls $W/root/etc/init.d 2>/dev/null
echo "--- systemd units"; ls $W/root/etc/systemd/system 2>/dev/null | head -40
grep -rl --include='*' -e 'mmcblk0p2' -e 'HOME' $W/root/etc 2>/dev/null | head -20
umount $W/root
