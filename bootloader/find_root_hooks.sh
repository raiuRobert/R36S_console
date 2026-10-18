#!/bin/bash
# Look for root-run scripts in the goodluckOS rootfs that read or run files from HOME, and for devmem.
IMG=/mnt/d/dev/R36s_console/firmware/goodluckos/ga36_a23_panel2_falcon.img
W=/tmp/glk; mkdir -p $W/root
mount -o ro,loop,offset=134217728 "$IMG" $W/root || exit 1
cd $W/root
grep -rIl '/home/player' etc usr/local/bin usr/local/sbin usr/sbin 2>/dev/null | head -20
echo "--- external-card.sh:"; sed -n 1,40p usr/local/bin/external-card.sh 2>/dev/null
echo "--- crontabs:"; ls -la etc/crontabs var/spool/cron/crontabs 2>/dev/null; cat etc/crontabs/* 2>/dev/null
echo "--- triggers:"; cat etc/triggerhappy/triggers.d/* 2>/dev/null | head -20
echo "--- devmem:"; ls -la bin/devmem sbin/devmem usr/bin/devmem usr/sbin/devmem 2>/dev/null; strings bin/busybox | grep -x devmem
echo "--- sudo/doas:"; ls usr/bin/sudo usr/bin/doas 2>/dev/null; cat etc/sudoers 2>/dev/null | grep -v '^#' | grep .
cd /; umount $W/root
