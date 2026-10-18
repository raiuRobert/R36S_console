#!/bin/bash
# Print U-Boot board defconfigs by name, e.g.: bash show_configs.sh sun8i_a23_evb q8_a23_tablet_800x480
cd ~/src/u-boot/configs
for name in "$@"; do
    echo "== ${name}_defconfig"
    cat "${name}_defconfig"
done
