#!/bin/bash
# Run the log build's boot-script logic in U-Boot sandbox (old hush), against a test disk with an
# MBR + FAT32 partition 2 holding the real goodluckOS zImage. Board-only commands are stubbed:
# gpio -> echo, ramlog -> setenv from the size of a test log, mmc read -> load from the FAT.
# Run as root (loop devices): bash test_bootcmd_sandbox.sh
set -euo pipefail
T=/tmp/sbtest; rm -rf $T; mkdir -p $T/mnt
truncate -s 96M $T/disk.img
printf 'label: dos\nstart=2048, size=40960, type=83\nstart=43008, type=c\n' | sfdisk -q $T/disk.img
L=$(losetup -f --show -P $T/disk.img)
mkfs.vfat -F 32 -n HOME ${L}p2 >/dev/null
mount ${L}p2 $T/mnt
cp /tmp/glk/zImage $T/mnt/zImage
umount $T/mnt; losetup -d $L

# Same script as CONFIG_BOOTCOMMAND, with the stubs; bootz is replaced by an echo.
CMD="host bind 0 $T/disk.img; setenv kernel_addr_r 0x1000000; setenv fdtcontroladdr 0x2000000; \
mw.b 0x3000000 0x41 0x40; mw.b 0x3000040 0x0a 1; \
echo; echo '=== GA36-MB mainline U-Boot, log build ==='; \
setenv savelog 'setenv ramlog_addr 0x3000000; setenv ramlog_size 0x41; fatwrite host 0:2 \${ramlog_addr} ga36_uboot.log \${ramlog_size}'; \
version; part list host 0; fatls host 0:2; run savelog; \
echo '--- loading the goodluckOS kernel'; \
if load host 0:2 \${kernel_addr_r} zImage; then echo 'kernel read OK'; else echo 'kernel read FAILED'; fi; \
md.l \${kernel_addr_r} 0x10; setexpr zmagic \${kernel_addr_r} + 0x24; \
if itest.l *\${zmagic} == 0x016f2818; then echo 'zImage magic OK'; else echo 'zImage magic WRONG'; fi; \
setenv bootm_boot_mode sec; printenv bootm_boot_mode zmagic; \
echo '--- bootz (stubbed)'; run savelog; fatls host 0:2; \
echo SCRIPT_END; reset"
cd /tmp/ub-sb
timeout 60 ./u-boot -c "$CMD" 2>&1 | tail -45
