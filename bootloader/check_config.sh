#!/bin/bash
# Show whether the given U-Boot config options are set in ~/src/u-boot/.config.
# Usage (inside WSL): bash check_config.sh USB_FUNCTION_ACM CONSOLE_MUX ...
cd ~/src/u-boot
for s in "$@"; do
    grep -E "^(# )?CONFIG_${s}[= ]" .config || echo "MISSING CONFIG_${s}"
done
