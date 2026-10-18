#!/bin/bash
# Build U-Boot "sandbox" (runs on the PC) to test boot-script syntax with the old hush parser,
# in a separate worktree (/tmp/ub-sb) so the board build tree stays as it is.
set -euo pipefail
cd ~/src/u-boot
[ -d /tmp/ub-sb ] || git worktree add -f --detach /tmp/ub-sb HEAD >/dev/null
cd /tmp/ub-sb
make -s sandbox_defconfig
./scripts/config -e HUSH_OLD_PARSER -d HUSH_MODERN_PARSER -d HUSH_SELECTABLE -e FAT_WRITE -e CMD_SETEXPR -e CMD_ITEST
make -s olddefconfig
NO_SDL=1 make -s -j"$(nproc)" u-boot 2>&1 | tail -5
ls -l u-boot
grep -E '^CONFIG_HUSH' .config
