#!/bin/bash
# Install the updated S00ga36log (with the root boot hook) into the goodluckOS rootfs of the card,
# attached to WSL with: wsl --mount \\.\PHYSICALDRIVE3 --partition 1 --type ext4
# Run in WSL as root: bash install_root_hook.sh [mount point]
set -euo pipefail
R=${1:-/mnt/wsl/PHYSICALDRIVE3p1}
SRC=/mnt/d/dev/R36s_console/bootloader/rootfs/S00ga36log
grep -q goodluckOS "$R/etc/os-release" 2>/dev/null || { echo "not the goodluckOS rootfs: $R"; ls "$R" 2>&1 | head; exit 1; }
cp "$R/etc/init.d/S00ga36log" /mnt/d/dev/R36s_console/logs/S00ga36log.card-before-hook.bak 2>/dev/null || true
install -m 0755 "$SRC" "$R/etc/init.d/S00ga36log"
sed -i 's/\r$//' "$R/etc/init.d/S00ga36log"
sh -n "$R/etc/init.d/S00ga36log" && echo "S00ga36log installed, syntax OK"
grep -n 'ga36_root_hook' "$R/etc/init.d/S00ga36log"
sync
