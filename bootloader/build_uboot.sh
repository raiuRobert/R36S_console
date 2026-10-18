#!/bin/bash
# Build mainline U-Boot for the GA36-MB with backlight blink codes.
# Run inside WSL: bash /mnt/d/dev/R36s_console/bootloader/build_uboot.sh [a23|a33|a23_diag|a33_diag|a23_fel|a23_log] (default a23)
#   GA36_RAMLOG=1  also mirror all console output into a DRAM buffer (ga36_ramlog.c, "ramlog"
#                  command) so the boot script can save it to the SD card. On for *_log targets.
#   *_log targets  also use the quiet SPL (backlight solid on, no blink codes; GA36_QUIET).
# Source: ~/src/u-boot (fetch_uboot.sh). Output: bootloader/out/u-boot-sunxi-with-spl.bin
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SRC=~/src/u-boot
OUT="$HERE/out"
SOC=${1:-a23}
DEFCONFIG=ga36mb_${SOC}_defconfig
cd "$SRC"

# Start every build from pristine sources, then apply our hooks.
git checkout -q board/sunxi/board.c board/sunxi/Makefile common/console.c arch/arm/dts/Makefile
rm -f board/sunxi/ga36_ramlog.c

cp "$HERE/configs/$DEFCONFIG" configs/
cp "$HERE/ga36_blink.h" board/sunxi/
cp "$HERE/dts/"*.dts arch/arm/dts/
sed -i 's|^\tsun8i-a23-q8-tablet.dtb|\tsun8i-a23-ga36mb.dtb \\\n\tsun8i-a23-q8-tablet.dtb|' arch/arm/dts/Makefile
grep -q 'sun8i-a23-ga36mb.dtb' arch/arm/dts/Makefile || { echo "dts Makefile hook missing"; exit 1; }

# Hook the blink calls into board/sunxi/board.c.
B=board/sunxi/board.c
sed -i 's|^#include <spl.h>$|#include <spl.h>\n#include "ga36_blink.h"|' "$B"
sed -i '/^void sunxi_board_init(void)$/,/^\tint power_failed = 0;$/ s|^\tint power_failed = 0;$|\tint power_failed = 0;\n\n\tga36_blink_start();|' "$B"
sed -i 's|^\tprintf("DRAM:");$|\tga36_blink_pmic(power_failed);\n\tprintf("DRAM:");|' "$B"
sed -i 's|^\tgd->ram_size = sunxi_dram_init();$|\tgd->ram_size = sunxi_dram_init();\n\tga36_blink_dram(gd->ram_size);|' "$B"
for f in 'ga36_blink.h' 'ga36_blink_start()' 'ga36_blink_pmic(' 'ga36_blink_dram('; do
    grep -q "$f" "$B" || { echo "hook missing: $f"; exit 1; }
done

case "$SOC" in
    *_log)
        GA36_RAMLOG=1
        sed -i 's|^#include "ga36_blink.h"$|#define GA36_QUIET\n#include "ga36_blink.h"|' "$B"
        grep -q '^#define GA36_QUIET' "$B" || { echo "hook missing: GA36_QUIET"; exit 1; }
        ;;
esac

if [ "${GA36_RAMLOG:-0}" = 1 ]; then
    echo "GA36_RAMLOG=1: adding the DRAM console log hooks"
    cp "$HERE/ga36_ramlog.c" board/sunxi/
    printf 'ifndef CONFIG_XPL_BUILD\nobj-y\t+= ga36_ramlog.o\nendif\n' >> board/sunxi/Makefile
    C=common/console.c
    sed -i 's|^\tconsole_record_putc(c);$|\tconsole_record_putc(c);\n#ifndef CONFIG_XPL_BUILD\n\t{ extern void ga36_ramlog_raw_putc(const char c); ga36_ramlog_raw_putc(c); }\n#endif|' "$C"
    sed -i 's|^\tconsole_record_puts(s);$|\tconsole_record_puts(s);\n#ifndef CONFIG_XPL_BUILD\n\t{ extern void ga36_ramlog_raw_puts(const char *s); ga36_ramlog_raw_puts(s); }\n#endif|' "$C"
    [ "$(grep -c 'ga36_ramlog_raw_put' "$C")" -ge 2 ] || { echo "console.c hook missing"; exit 1; }
    sed -i '/^int board_late_init(void)$/{n;s|^{$|{\n\textern int ga36_ramlog_init(void);\n\n\tga36_ramlog_init();|}' "$B"
    grep -q 'ga36_ramlog_init()' "$B" || { echo "hook missing: ga36_ramlog_init()"; exit 1; }
fi

export CROSS_COMPILE=arm-linux-gnueabihf-
make -s "$DEFCONFIG"
make -s -j"$(nproc)"

mkdir -p "$OUT"
cp u-boot-sunxi-with-spl.bin "$OUT/"
ls -l "$OUT/u-boot-sunxi-with-spl.bin"
head -c 64 "$OUT/u-boot-sunxi-with-spl.bin" | xxd | head -2
