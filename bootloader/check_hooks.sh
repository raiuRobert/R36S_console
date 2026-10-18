#!/bin/bash
# Show which GA36 hooks are present in the current U-Boot build tree.
cd ~/src/u-boot
echo "console.c ramlog hooks: $(grep -c ga36_ramlog common/console.c)"
echo "board.c ramlog init:    $(grep -c ga36_ramlog_init board/sunxi/board.c)"
echo "board.c blink hooks:    $(grep -c ga36_blink board/sunxi/board.c)"
echo "ramlog symbols in map:  $(grep -c ga36_ramlog u-boot.map)"
strings u-boot.bin | grep -m1 '^bootcmd=' | cut -c1-120
