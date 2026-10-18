#!/bin/bash
# Sanity checks on the last U-Boot build (WSL): config symbols, hooks, and the strings that matter.
cd ~/src/u-boot
grep -E '^(CONFIG_FAT_WRITE|CONFIG_CMD_FAT|CONFIG_CMD_PART|CONFIG_CMD_SETEXPR|CONFIG_CMD_ITEST|CONFIG_CMD_BDI|CONFIG_ENV_IS_IN_FAT|CONFIG_ENV_FAT_DEVICE_AND_PART|CONFIG_SUNXI_MINIMUM_DRAM_MB|CONFIG_VIDEO_SUNXI|CONFIG_USB_MUSB_GADGET|CONFIG_USB_EHCI_HCD|CONFIG_SYS_MALLOC_LEN|CONFIG_TEXT_BASE|CONFIG_HUSH_PARSER|CONFIG_HUSH_MODERN_PARSER|CONFIG_HUSH_OLD_PARSER)=' .config
grep -n 'GA36_QUIET\|ga36_blink_\|ga36_ramlog_init' board/sunxi/board.c
grep -c 'ga36_ramlog_raw_put' common/console.c
strings -n 6 u-boot.bin | grep -E 'ramlog|ga36_uboot.log|GA36-MB mainline|bootm_boot_mode sec' | head
arm-linux-gnueabihf-nm u-boot | grep -E 'ga36_ramlog|_u_boot_list_2_cmd_2_ramlog' 
arm-linux-gnueabihf-objdump -d spl/u-boot-spl | grep -c 'ga36_flashes\|mdelay' 
ls -l spl/u-boot-spl.bin u-boot.bin
