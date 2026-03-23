#include "platform.h"

static uint32_t boot_loaded;

static void banner(void)
{
    uart_puts("RV32 PC\n");
    uart_puts("h=help l=led b=boot k=ps2 g=go\n> ");
}

static void show_ps2_status(void)
{
    if ((PS2_STATUS == 0x1u) && ((PS2_DATA & 0xFFu) == 0x1Cu)) {
        uart_puts("PS2=OK\n> ");
    } else {
        uart_puts("PS2=ER\n> ");
    }
}

static void show_help(void)
{
    uart_puts("CMDS:h l b k g\n> ");
}

static void retry_sd_boot(void)
{
    static const uint8_t expected_header[] = {
        0x52u, 0x56u, 0x50u, 0x43u,
        0x00u, 0x00u, 0x00u, 0x10u,
        0x1Cu, 0x00u, 0x00u, 0x00u,
        0x00u, 0x00u, 0x00u, 0x10u,
        0x49u, 0x5Eu, 0xD5u, 0x45u,
        0x01u, 0x00u, 0x00u, 0x00u,
        0x00u, 0x00u, 0x00u, 0x00u,
        0x00u, 0x00u, 0x00u, 0x00u,
    };
    volatile uint8_t *dst = (volatile uint8_t *)SRAM_BASE;
    unsigned int i;

    spi_set_divider(250u);
    boot_loaded = 0u;
    for (i = 0; i < sizeof(expected_header); ++i) {
        if (spi_transfer_byte(0xFFu) != expected_header[i]) {
            uart_puts("BOOT=ER\n> ");
            return;
        }
    }

    for (i = 0; i < 28u; ++i) {
        dst[i] = spi_transfer_byte(0xFFu);
    }

    boot_loaded = 1u;
    uart_puts("BOOT=OK\n> ");
}

static void run_loaded_program(void)
{
    void (*entry)(void) = (void (*)(void))SRAM_BASE;

    if (!boot_loaded) {
        uart_puts("GO=ER\n> ");
        return;
    }

    entry();
    uart_puts("GO=RET\n> ");
}

int main(void)
{
    uint32_t led_value = 1u;

    uart_set_divider(868u);
    gpio_write(led_value);
    banner();

    for (;;) {
        int ch = uart_try_getc();
        if (ch >= 0) {
            uart_putc((char)ch);
            uart_putc('\r');
            uart_putc('\n');

            switch ((char)ch) {
            case 'h':
            case '?':
                show_help();
                break;
            case 'b':
                retry_sd_boot();
                break;
            case 'k':
                show_ps2_status();
                break;
            case 'g':
                run_loaded_program();
                break;
            case 'l':
                led_value ^= 1u;
                gpio_write(led_value);
                uart_puts(led_value ? "LED=1\n> " : "LED=0\n> ");
                break;
            default:
                uart_puts("?\n> ");
                break;
            }
        }
    }
}
