# GA36-MB (R36S clone, Allwinner A23) — bootloader build log, 2026-10-17 afternoon

## What was wrong with the earlier tests

- The chip is an **Allwinner A23** (FEL: `soc=00001650`). Every SD-card U-Boot test until 16:40
  used the **A33** SPL, which resets the chip during DRAM init on this A23 (decoded from your
  video). That is the endless 2 s on / 1 s off blink. The boot scripts never even ran.
- The A23 SPL initialises DRAM correctly (FEL memory test, 8/8 regions OK).
- A23 U-Boot *proper* (the second stage) never showed a sign of life over FEL. Its console
  was on a UART that U-Boot cannot clock; that is fixed, but the fix was never confirmed.

## What I built (all in `bootloader/`, outputs in `bootloader/out/`, `firmware/goodluckos/`)

| Item | What it does |
|---|---|
| `configs/ga36mb_a23_falcon_log_defconfig` | **Falcon mode**: the proven A23 SPL loads the Linux kernel straight from the card and jumps to it (secure mode, like the stock loader). U-Boot proper is skipped entirely. |
| `configs/ga36mb_a23_log_defconfig` | Fallback U-Boot proper: no blink codes; writes its whole console output to `ga36_uboot.log` on the card's FAT partition, then boots the kernel. Used only if the falcon kernel image is missing or invalid. |
| `ga36_blink.h` (`GA36_QUIET`) | Log builds: backlight **solid on** from power-on, no blink codes. Only a DRAM failure blinks (fast). |
| `ga36_ramlog.c` | Console log in DRAM plus a `ramlog` command, so the boot script can save it with `fatwrite`. |
| `rootfs/S00ga36log` | goodluckOS init script: saves `dmesg`, display, USB, power and process info to `ga36_linux_1/2/3.log` on the HOME partition at boot, +20 s and +60 s. |
| `make_log_image.sh`, `make_falcon_image.sh` | Build the card images from goodluckOS 0.1.0 `a23_panel1`. |
| `fel_linux.sh` | Boots the same kernel over USB FEL (SPL → kernel), with nothing written to the card. |
| `test_bootcmd_sandbox.sh` | Runs the boot script in U-Boot "sandbox" on the PC. The script logic passed. |

### Card image ready to write: `firmware/goodluckos/ga36_a23_panel1_falcon.img`
sha256 `1f9a5ed474cdbf3c6c066544baf0ad261c767dd5e66e1229438674f559a69ccf`

| SD offset | Content |
|---|---|
| 8 KiB | SPL (falcon, quiet, 19.5 KB) + U-Boot proper (log build) |
| sector 0x1000 (2 MiB) | copy of the kernel DTB (falcon "args") |
| sector 0x2000 (4 MiB) | uImage: goodluckOS 7.2.9 zImage + appended A23 DTB, load/entry 0x42000000 |
| 84 MiB | original goodluckOS Android boot image (used by the fallback U-Boot) |
| 128 MiB | goodluckOS rootfs (ext4), with `S00ga36log` added (e2fsck clean) |
| 512 MiB | HOME (FAT32), where the logs appear |

All parts were verified by reading them back from the image.

Panel-2 variant: `firmware/goodluckos/ga36_a23_panel2_falcon.img` (sha256 `3507dc8e…`), built
the same way from goodluckOS `a23_panel2`. Use it if panel 1 gives a lit but blank screen;
goodluckOS says there's no way to tell the two panels apart in advance.
Write with `write_card_falcon.cmd` (panel 1) or `write_card_falcon.cmd 2` (panel 2).

## Results (17:50–18:05)

1. **Panel 1 falcon card:** Linux and goodluckOS came fully up (logs in `logs/boot1/`). The
   screen stayed blank, because the panel 1 init sequence is wrong for this panel. All USB was
   dead too: the USB PHY waits for the AXP `drivevbus` regulator, and Linux only registers that
   regulator when the PMIC node has `x-powers,drive-vbus-en`, which this DTB was missing.
2. `make_falcon_image.sh` now adds that property to the kernel's appended DTB (falcon path).
3. **Panel 2 falcon card + USB fix: WORKS.** The goodluckOS setup/menu is on screen, and
   Windows sees **COM4** (USB serial with a login prompt) plus an **MTP** device.
   → This unit is **A23 + panel 2**. Card image: `firmware/goodluckos/ga36_a23_panel2_falcon.img`
   (sha256 `d45243af…`).

## Findings inside goodluckOS (helpful later)

- Kernel 7.2.9. The cmdline is built in: `root=/dev/mmcblk0p1 rootfstype=ext4 rootwait rw init=/sbin/init coherent_pool=4m loglevel=8`. The kernel brings up the MIPI-DSI jd9366 panel itself, so the bootloader doesn't need any display code.
- BusyBox init. `S30usb-gadget` turns the OTG port into a USB device for the PC: **serial console (ACM) + MTP**. A `getty` runs on `ttyGS0`. Once Linux is up, the PC gets a COM port with a login prompt: the terminal you wanted. Log in with goodluckOS's own account; I never touch passwords.
- `S01resize-home` only grows HOME when a request flag is set, so it won't wipe the logs.

## Internet research

- goodluckOS issue #42: a GA36-MB **A23** owner booted goodluckOS by keeping the stock
  bootloader from their original card. Audio and USB-OTG then needed DTS fixes, which are in
  goodluckOS 0.1.0.
- The goodluckOS Firmware Builder always needs your own stock card's first 128 MB. There's no
  public A23 bootloader dump yet; it is planned in issue #74. Your original card is gone, so the
  mainline-U-Boot route is the only one left.
- CodeZombie's GA36-MB investigation gist has the stock boot0/boot1 offsets and notes that the
  UART pads are 3.0 V logic.

## Blocked right now

- The USB FEL boot ROM hung at 16:44. My test script wrote to DRAM before the SPL had
  initialised it; that bug is fixed now. Windows shows "Device Descriptor Request Failed" until
  the console's **RST** is pressed.
- Writing the card needs your UAC approval: `write_card_falcon.cmd`.
