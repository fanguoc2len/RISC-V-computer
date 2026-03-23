#include "platform.h"

static void put_hex_digit(uint32_t value)
{
    value &= 0xFu;
    uart_putc(value < 10 ? ('0' + value) : ('A' + value - 10));
}

static void put_hex32(uint32_t value)
{
    int shift;
    for (shift = 28; shift >= 0; shift -= 4) {
        put_hex_digit(value >> shift);
    }
}

static void banner(void)
{
    uart_puts("\nRISC-V PicoRV32 Computer\n");
    uart_puts("Board  : Basys3\n");
    uart_puts("CPU    : PicoRV32\n");
    uart_puts("SRAM   : 64 KB @ 0x10000000\n");
    uart_puts("Boot   : ROM -> SPI/SD -> SRAM\n");
    uart_puts("\nCommands:\n");
    uart_puts("  h : help\n");
    uart_puts("  b : retry SD boot (stub)\n");
    uart_puts("  k : read PS/2 state\n");
    uart_puts("\n");
}

static void show_ps2_status(void)
{
    if ((PS2_STATUS == 0x1u) && ((PS2_DATA & 0xFFu) == 0x1Cu)) {
        uart_puts("PS2=OK\n");
    } else {
        uart_puts("PS2=ER\n");
    }
}

static void show_help(void)
{
    uart_puts("System ready. Waiting on UART/SPI/PS2.\n");
}

static void retry_sd_boot(void)
{
    uint8_t rx;

    spi_set_divider(250u);
    rx = spi_transfer_byte(0xA5u);

    uart_puts("SPI=");
    if (rx == 0x3Cu) {
        uart_puts("OK\n");
    } else {
        uart_puts("ER\n");
    }
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
            case 'l':
                led_value ^= 1u;
                gpio_write(led_value);
                uart_puts("LED toggled.\n");
                break;
            default:
                uart_puts("Unknown command.\n");
                break;
            }
        }

        if (PS2_STATUS & 0x1u) {
            uart_puts("PS/2 scancode = 0x");
            put_hex32(PS2_DATA);
            uart_puts("\n");
        }
    }
}
