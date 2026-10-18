// SPDX-License-Identifier: GPL-2.0+
/*
 * Console log for the GA36-MB: every character U-Boot proper prints (via the global putc()/
 * puts() in common/console.c, hooked by build_uboot.sh) is appended to a buffer in DRAM, from
 * the very first message on. The boot script saves it to the SD card's FAT partition as a plain
 * text file (fatwrite), so it can be read on a PC: no serial adapter is attached to this board.
 *
 *   ramlog            set ${ramlog_addr} / ${ramlog_size} to the text written so far
 *
 * Layout: 16-byte header { magic "RLOG", length, 0, 0 } followed by the text.
 * DRAM is already initialised by the SPL when U-Boot proper starts, so the buffer can be used
 * from the first character. (On-chip SRAM A2 is not usable: PSCI is installed there.)
 * A "ramlog" stdio device is also registered (from board_late_init) so existing
 * "setenv stdout serial,ramlog" commands keep working; it adds nothing itself.
 */
#include <command.h>
#include <env.h>
#include <stdio_dev.h>
#include <linux/string.h>
#include <linux/types.h>

/* 0x4f800000: above the kernel/fdt/ramdisk load addresses, far below U-Boot's relocation. */
#define RAMLOG_BASE	0x4f800000UL
#define RAMLOG_SIZE	0x00100000UL
#define RAMLOG_MAGIC	0x474f4c52	/* "RLOG" */

struct ramlog_hdr {
	u32 magic;
	u32 len;
	u32 reserved[2];
};

static struct ramlog_hdr *const hdr = (struct ramlog_hdr *)RAMLOG_BASE;
/* In .data so it survives relocation (the image, including .data, is copied as it is). */
static int ramlog_started = 0;

void ga36_ramlog_raw_putc(const char c)
{
	char *buf = (char *)(RAMLOG_BASE + sizeof(*hdr));

	if (!ramlog_started) {
		ramlog_started = 1;
		hdr->magic = RAMLOG_MAGIC;
		hdr->len = 0;
		hdr->reserved[0] = 0;
		hdr->reserved[1] = 0;
	}
	if (hdr->len < RAMLOG_SIZE - sizeof(*hdr))
		buf[hdr->len++] = c;
}

void ga36_ramlog_raw_puts(const char *s)
{
	while (*s)
		ga36_ramlog_raw_putc(*s++);
}

static void ramlog_dev_putc(struct stdio_dev *dev, const char c)
{
}

static void ramlog_dev_puts(struct stdio_dev *dev, const char *s)
{
}

int ga36_ramlog_init(void)
{
	struct stdio_dev dev;

	memset(&dev, 0, sizeof(dev));
	strcpy(dev.name, "ramlog");
	dev.flags = DEV_FLAGS_OUTPUT;
	dev.putc = ramlog_dev_putc;
	dev.puts = ramlog_dev_puts;
	return stdio_register(&dev);
}

static int do_ramlog(struct cmd_tbl *cmdtp, int flag, int argc, char *const argv[])
{
	env_set_hex("ramlog_addr", RAMLOG_BASE + sizeof(*hdr));
	env_set_hex("ramlog_size", ramlog_started ? hdr->len : 0);
	return 0;
}

U_BOOT_CMD(ramlog, 1, 0, do_ramlog,
	   "set ramlog_addr/ramlog_size to the console log in DRAM",
	   "");
