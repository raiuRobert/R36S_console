/*
 * Sign-of-life probe v2 for the GA36-MB R36S clone (Allwinner A23/A33), no serial needed.
 * Pins come from the stock script.bin (research/stock_boot/script.fex): backlight PWM0 = PH0,
 * debug UART2 = PB0/PB1 (still printed to, for whoever has an adapter).
 *
 * What you see on the screen backlight:
 *   1. ON solid for ~8 s  -> power stays up (if it dies within ~1 s, the board is losing power)
 *   2. then, repeating:   dark 3 s, N short flashes = chip ID
 *        2 flashes = A23 (0x1650)   3 flashes = A33 (0x1667)   5 flashes = unknown ID
 *      followed by one long 1.5 s flash if the 24 MHz timer works (none if it had to fall back
 *      to a CPU busy-loop, in which case all timings may run fast or slow).
 */
#define REG(a) (*(volatile unsigned int *)(a))

#define SRAMC 0x01C00000u
#define CCU   0x01C20000u
#define PIO   0x01C20800u
#define TIMER 0x01C20C00u
#define UART2 0x01C28800u

enum { PB = 1, PH = 7 };

static int timer_ok;

static void pin_func(int port, int pin, unsigned func)
{
    unsigned r = PIO + port * 0x24 + (pin / 8) * 4;
    int sh = (pin % 8) * 4;
    REG(r) = (REG(r) & ~(7u << sh)) | (func << sh);
}

static void pin_out(int port, int pin, int on)
{
    unsigned r = PIO + port * 0x24 + 0x10;
    if (on)
        REG(r) |= 1u << pin;
    else
        REG(r) &= ~(1u << pin);
}

static void spin(unsigned n)
{
    while (n--)
        __asm__ volatile("nop");
}

/* Timer0 as a free-running down-counter at 24 MHz; checks that it actually counts. */
static void timer_init(void)
{
    REG(TIMER + 0x14) = 0xFFFFFFFFu;            /* TMR0_INTV */
    REG(TIMER + 0x10) = (1u << 2) | (1u << 1);  /* src OSC24M, reload */
    for (int i = 0; i < 100000 && (REG(TIMER + 0x10) & (1u << 1)); i++)
        ;
    REG(TIMER + 0x10) |= 1u;                    /* enable */
    unsigned a = REG(TIMER + 0x18);
    spin(200000);
    timer_ok = REG(TIMER + 0x18) != a;
}

static void delay_ms(unsigned ms)
{
    if (timer_ok) {
        unsigned start = REG(TIMER + 0x18);
        while (start - REG(TIMER + 0x18) < ms * 24000u)
            ;
    } else {
        while (ms--)
            spin(100000);   /* rough guess; the real speed depends on the BROM CPU clock */
    }
}

static void uart_init(void)
{
    REG(CCU + 0x06C) |= 1u << 18;   /* UART2 bus clock gate */
    REG(CCU + 0x2D8) |= 1u << 18;   /* UART2 out of reset */
    pin_func(PB, 0, 2);             /* PB0 = UART2_TX */
    pin_func(PB, 1, 2);             /* PB1 = UART2_RX */
    REG(UART2 + 0x04) = 0;
    REG(UART2 + 0x08) = 0x07;
    REG(UART2 + 0x0C) = 0x83;
    REG(UART2 + 0x00) = 13;         /* 24 MHz / (16 * 13) ~ 115200 baud */
    REG(UART2 + 0x04) = 0;
    REG(UART2 + 0x0C) = 0x03;
}

static void puts_(const char *s)
{
    for (; *s; s++) {
        for (int i = 0; i < 200000 && !(REG(UART2 + 0x14) & (1u << 5)); i++)
            ;                       /* bounded: never hang on a dead UART */
        REG(UART2) = (unsigned)*s;
    }
}

static void puthex(unsigned v)
{
    char buf[9];
    for (int i = 7; i >= 0; i--, v >>= 4)
        buf[i] = "0123456789abcdef"[v & 15];
    buf[8] = 0;
    puts_(buf);
}

static unsigned chip_id(void)
{
    REG(SRAMC + 0x24) |= 1u << 15;  /* make the version field readable */
    return REG(SRAMC + 0x24) >> 16;
}

static void backlight(int on)
{
    pin_out(PH, 0, on);
}

int main(void)
{
    REG(CCU + 0x068) |= 1u << 5;    /* PIO bus clock gate */
    pin_func(PH, 0, 1);             /* backlight PWM pin as plain output */
    backlight(1);                   /* on first, before anything that could hang */

    timer_init();
    uart_init();
    unsigned id = chip_id();
    int flashes = id == 0x1650 ? 2 : id == 0x1667 ? 3 : 5;

    puts_("\r\n[R36S probe v2] running. chip id 0x");
    puthex(id);
    puts_(timer_ok ? " timer ok\r\n" : " timer NOT counting\r\n");

    delay_ms(8000);                 /* stage 1: solid on */

    for (;;) {
        backlight(0);
        delay_ms(3000);
        for (int i = 0; i < flashes; i++) {
            backlight(1);
            delay_ms(400);
            backlight(0);
            delay_ms(400);
        }
        if (timer_ok) {
            delay_ms(800);
            backlight(1);
            delay_ms(1500);
        }
        puts_("[R36S probe v2] chip id 0x");
        puthex(id);
        puts_("\r\n");
    }
}
