/* SPDX-License-Identifier: GPL-2.0+ */
/*
 * GA36-MB (R36S clone, Allwinner A23) boot progress shown on the LCD backlight,
 * because the board has no screen driver in U-Boot and no serial adapter is attached.
 * Backlight = PWM0 pin PH0 driven as a plain GPIO (from the stock script.bin).
 *
 *   SPL start : backlight ON 2 s, off 1 s, then chip flashes: 2 = A23, 3 = A33, 5 = other
 *   PMIC      : off 1 s, then 1 short flash = AXP ok, 1 long (2 s) flash = AXP failed
 *   DRAM      : off 1 s, then N flashes = DRAM size / 128 MiB, then ON solid
 *               fast blinking forever = DRAM init failed
 *
 * The delays matter: the "fast" variant without them (DRAM init and full CPU clock right after
 * the AXP voltages are set) made every boot restart-loop on this board, while this one works.
 */
#ifndef _GA36_BLINK_H
#define _GA36_BLINK_H

#ifdef CONFIG_XPL_BUILD
#include <asm/io.h>
#include <asm/arch/cpu.h>
#include <linux/delay.h>

#define GA36_PH_CFG0	(SUNXI_PIO_BASE + 7 * 0x24)
#define GA36_PH_DAT	(SUNXI_PIO_BASE + 7 * 0x24 + 0x10)

static void ga36_bl(int on)
{
	clrsetbits_le32(GA36_PH_CFG0, 0x7, 0x1);	/* PH0 = output */
	if (on)
		setbits_le32(GA36_PH_DAT, 1);
	else
		clrbits_le32(GA36_PH_DAT, 1);
}

static void ga36_flashes(int n, int on_ms, int off_ms)
{
	while (n-- > 0) {
		ga36_bl(1);
		mdelay(on_ms);
		ga36_bl(0);
		mdelay(off_ms);
	}
}

#ifdef GA36_QUIET
/*
 * Quiet variant (log builds): backlight solid ON from the SPL start, with the same delays as
 * the blink variant; only a DRAM init failure blinks (fast, forever).
 */
static void ga36_blink_start(void)
{
	ga36_bl(1);
	mdelay(3000);
}

static void ga36_blink_pmic(int power_failed)
{
	mdelay(2000);
}

static void ga36_blink_dram(unsigned long size)
{
	if (!size) {
		for (;;)
			ga36_flashes(1, 100, 100);
	}
	ga36_bl(1);
}
#else
static void ga36_blink_start(void)
{
	u32 id;

	setbits_le32(SUNXI_SRAMC_BASE + 0x24, 1 << 15);
	id = readl(SUNXI_SRAMC_BASE + 0x24) >> 16;
	clrbits_le32(SUNXI_SRAMC_BASE + 0x24, 1 << 15);

	ga36_bl(1);
	mdelay(2000);
	ga36_bl(0);
	mdelay(1000);
	ga36_flashes(id == 0x1650 ? 2 : id == 0x1667 ? 3 : 5, 400, 400);
}

static void ga36_blink_pmic(int power_failed)
{
	mdelay(1000);
	if (power_failed)
		ga36_flashes(1, 2000, 400);
	else
		ga36_flashes(1, 300, 400);
	mdelay(600);
}

static void ga36_blink_dram(unsigned long size)
{
	if (!size) {
		for (;;)
			ga36_flashes(1, 100, 100);
	}
	ga36_flashes((int)(size >> 27), 400, 400);	/* one flash per 128 MiB */
	ga36_bl(1);
}
#endif /* GA36_QUIET */

#ifdef CONFIG_SPL_OS_BOOT
/*
 * Falcon mode: always try to boot Linux straight from the SPL (raw uImage on the SD card);
 * the SPL falls back to U-Boot proper by itself when there is no valid kernel image.
 */
int spl_start_uboot(void)
{
	return 0;
}
#endif
#endif /* CONFIG_XPL_BUILD */

#endif /* _GA36_BLINK_H */
