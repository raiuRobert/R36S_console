# R36S clone (GA36-MB) repair — project handoff

Goal: make a used R36S handheld bought on OLX work, then run games on it. Repo: github.com/raiuRobert/R36S_console.
Details of every file: see the file list in `logs/bootloader_build_log.md` and the headers of each script.

## The hardware (verified)
- Board **GA36-MB V1.1-20251025**. The SoC says "Rockchip RK3326" but is really an **Allwinner A23** (`sunxi-fel version` -> `soc=00001650(A23)`), 2 cores, 32-bit.
- PMIC marked RK817 is an **AXP223** (RSB 0x34). RAM: 2x Nanya DDR3, 512 MB. Screen: jd9366 MIPI-DSI 640x480, **panel 2** (goodluckOS `panel-id = 2`); the LCD has a cracked bottom-left corner.
- Pins (from the stock A33 `research/stock_boot/script.fex`, so treat as approximate): backlight PWM0 = PH0; debug UART2 = PB0/PB1 (TX/RX pads, 3.0 V, no adapter available); buttons on port E.
- Rockchip images (dArkOS, ArkOS4Clone) can never boot here. The stock backup in use was an A33 board; the user's original card was fake and is gone.

## Current state (as of 2026-10-18 ~03:00)
- The SD card in TF1 boots **goodluckOS 0.1.0 (Linux 7.2.9) A23 panel 2** to its Welcome/menu screen. Boot works on its own.
- Boot chain: Boot ROM -> **A23 SPL** (U-Boot v2026.10 built by `bootloader/build_uboot.sh a23_falcon_log`, "falcon mode") -> loads a legacy uImage of the kernel (zImage + appended DTB) from SD sector 0x2000 (4 MiB), DTB copy at sector 0x1000 -> Linux. U-Boot proper is skipped (it never showed a sign of life over FEL; it stays on the card only as an unproven fallback).
- Card layout: 8 KiB SPL+U-Boot, 2 MiB DTB copy, 4 MiB uImage, 84 MiB goodluckOS Android boot image (unused), 128 MiB rootfs ext4 (p1), 512 MiB HOME FAT32 (p2, `/home/player`). Image: `firmware/goodluckos/ga36_a23_panel2_falcon.img` (not in git: 109 GB of firmware is ignored).
- DTB fixes applied by `bootloader/make_falcon_image.sh`: USB `dr_mode=peripheral`, no `usb0_vbus-supply` (an earlier `x-powers,drive-vbus-en` made USB work but is not used now).
- **Open problem:** the OTG USB-C port works as a device (COM4 serial with login prompt + MTP), but the PC resets the link every 2-8 s at high speed (`logs/usbdebug/`). Another port/cable reduced but did not stop it. A root boot hook forces full speed (MUSB POWER register 0x01c19040: 0xF0 -> 0xC0; `logs/roothook/`); the log then showed no resets, **but the console disappeared from the PC at 02:55:41 and the cause is unknown** (last question to the user: is it still on with the cable plugged in?).
- Not done yet: a working terminal (serial login on COM4 needs the user's own login; never handle passwords), keyboard on the console's USB-C port (needs host mode / kernel rebuild: FRAMEBUFFER_CONSOLE, USB HID, host on OTG), PortMaster (practically infeasible on a 32-bit A23; goodluckOS has none).

## How to work on it
- Windows 11 host + WSL2 Ubuntu-24.04 (user `rober`, root via `wsl -u root`). U-Boot source in WSL `~/src/u-boot` (build there, not on /mnt/d). From Git Bash call `MSYS_NO_PATHCONV=1 wsl.exe ... bash /mnt/d/dev/R36s_console/...` and keep logic in script files (`$vars` in `bash -c` get expanded early).
- Python for the card tools: `C:\msys64\mingw64\bin\python.exe -I tools\flash_sd.py <image> <disk> [sync]`. Writing the card needs an elevated process (user approves the UAC prompt). The card is Windows disk 3 (31,281,119,232 bytes); always re-check the disk number and size.
- Changing things without taking the card out: copy `bootloader/home/ga36_root_hook.sh` to the console's HOME over MTP (`tools/mtp_put.ps1`); `rootfs/S00ga36log` runs it **as root** at the next boot and its output lands in `ga36_root_hook.log` (`tools/mtp_grab.ps1` reads it back). Security note: anyone who can write HOME can run root code at boot, so remove that block before the console is shared.
- USB recovery (FEL, VID 1f3a): `usbipd` 5.3.0, busid of the console varies (1-13/1-14). One-shot `usbipd attach --wsl --busid X`, never `--auto-attach`. Clear stale ports with `echo N > /sys/devices/platform/vhci_hcd.0/detach`. Run the A23 SPL only once per FEL session; never write DRAM before the SPL ran; RST needed after a hang.
- Phone videos of the backlight can be decoded with `tools/backlight_timeline.py`.

## Rules from the user
- Never enter or handle passwords; the user types their own and approves every UAC prompt.
- Do not make the user swap cards more than needed; the user has said "I won't change the card" — use whatever card is in the reader (currently the 32 GB card).
- No serial adapter: avoid plans that need one (offered once, declined).
- Commit trailers: `Co-Authored-By: <the model> <noreply@anthropic.com>`; PR bodies end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Next steps (suggested)
1. Find out why the console left the PC's USB at 02:55:41 after the full-speed switch (check whether it was only the PC side; read `ga36_root_hook.log` again).
2. Once USB is stable: open COM4 (`python -m serial.tools.miniterm COM4 115200`) and log in with the user's own credentials.
3. Then: keyboard + on-screen terminal (kernel rebuild), then decide what games are realistic.
