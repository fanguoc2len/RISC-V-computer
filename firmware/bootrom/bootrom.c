#include "platform.h"

#define BOOT_INFO_MAGIC 0x49425652u
#define BOOT_INFO_WORDS 8u
#define BOOT_STATUS_OK 0x00000001u
#define BOOT_STATUS_BAD_MAGIC 0x000000E1u
#define BOOT_STATUS_BAD_RANGE 0x000000E2u
#define BOOT_STATUS_BAD_SIZE 0x000000E3u
#define BOOT_STATUS_BAD_ENTRY 0x000000E4u
#define BOOT_STATUS_BAD_CHECKSUM 0x000000E5u

static uint32_t boot_loaded;
static uint32_t boot_entry_addr;

static volatile uint32_t *const boot_info = (volatile uint32_t *)(uintptr_t)SRAM_BASE;

static uint32_t spi_read_u32_le(void)
{
    uint32_t value = 0u;

    value |= (uint32_t)spi_transfer_byte(0xFFu);
    value |= (uint32_t)spi_transfer_byte(0xFFu) << 8;
    value |= (uint32_t)spi_transfer_byte(0xFFu) << 16;
    value |= (uint32_t)spi_transfer_byte(0xFFu) << 24;
    return value;
}

static void banner(void)
{
    uart_puts("RV32 PC\n");
    uart_puts("h=help l=led b=boot k=ps2 i=info m=mem t=time g=go\n> ");
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
    uart_puts("CMDS:h l b k i m t g\n> ");
}

static void uart_put_hex32(uint32_t value)
{
    int shift;

    for (shift = 28; shift >= 0; shift -= 4) {
        uint32_t nibble = (value >> (uint32_t)shift) & 0xFu;
        uart_putc((char)(nibble < 10u ? ('0' + nibble) : ('A' + (nibble - 10u))));
    }
}

static void show_boot_info(void)
{
    uart_puts("BOOTLD=");
    uart_putc((char)(boot_loaded ? '1' : '0'));
    uart_puts(" ENTRY=");
    uart_put_hex32(boot_entry_addr);
    uart_puts(" STATUS=");
    uart_put_hex32(boot_info[5]);
    uart_puts("\n> ");
}

static void dump_memory_snapshot(void)
{
    uart_puts("BI0=");
    uart_put_hex32(boot_info[0]);
    uart_puts(" APP0=");
    uart_put_hex32(REG32(boot_info[1]));
    uart_puts("\n> ");
}

static void show_time_snapshot(void)
{
    uart_puts("TIME=");
    uart_put_hex32(TIMER_COUNT_LO);
    uart_puts("\n> ");
}

static void clear_boot_info(void)
{
    unsigned int i;

    for (i = 0; i < BOOT_INFO_WORDS; ++i) {
        boot_info[i] = 0u;
    }
}

static void write_boot_info(uint32_t load_addr, uint32_t size_bytes, uint32_t entry_addr, uint32_t checksum)
{
    boot_info[0] = BOOT_INFO_MAGIC;
    boot_info[1] = load_addr;
    boot_info[2] = size_bytes;
    boot_info[3] = entry_addr;
    boot_info[4] = checksum;
    boot_info[5] = BOOT_STATUS_OK;
    boot_info[6] = 0u;
    boot_info[7] = 0u;
}

static void retry_sd_boot(void)
{
    uint32_t magic;
    uint32_t load_addr;
    uint32_t size_bytes;
    uint32_t entry_addr;
    uint32_t expected_checksum;
    uint32_t version;
    uint32_t reserved0;
    uint32_t reserved1;
    uint32_t load_offset;
    uint32_t checksum;
    uint32_t checksum_word;
    volatile uint8_t *dst;
    unsigned int i;

    spi_set_divider(250u);
    boot_loaded = 0u;
    boot_entry_addr = 0u;
    clear_boot_info();
    magic = spi_read_u32_le();
    load_addr = spi_read_u32_le();
    size_bytes = spi_read_u32_le();
    entry_addr = spi_read_u32_le();
    expected_checksum = spi_read_u32_le();
    version = spi_read_u32_le();
    reserved0 = spi_read_u32_le();
    reserved1 = spi_read_u32_le();

    if (magic != 0x43505652u) {
        boot_info[5] = BOOT_STATUS_BAD_MAGIC;
        uart_puts("BOOT=ER\n> ");
        return;
    }

    if ((version != 1u) || (reserved0 != 0u) || (reserved1 != 0u)) {
        boot_info[5] = BOOT_STATUS_BAD_MAGIC;
        uart_puts("BOOT=ER\n> ");
        return;
    }

    if ((load_addr < SRAM_BASE) || (size_bytes == 0u)) {
        boot_info[5] = (size_bytes == 0u) ? BOOT_STATUS_BAD_SIZE : BOOT_STATUS_BAD_RANGE;
        uart_puts("BOOT=ER\n> ");
        return;
    }

    load_offset = load_addr - SRAM_BASE;
    if (load_offset > SRAM_SIZE_BYTES || size_bytes > (SRAM_SIZE_BYTES - load_offset)) {
        boot_info[5] = BOOT_STATUS_BAD_RANGE;
        uart_puts("BOOT=ER\n> ");
        return;
    }

    if ((entry_addr < load_addr) || (entry_addr >= (load_addr + size_bytes))) {
        boot_info[5] = BOOT_STATUS_BAD_ENTRY;
        uart_puts("BOOT=ER\n> ");
        return;
    }

    dst = (volatile uint8_t *)(uintptr_t)load_addr;
    checksum = 0u;
    checksum_word = 0u;
    for (i = 0; i < size_bytes; ++i) {
        uint8_t byte = spi_transfer_byte(0xFFu);

        dst[i] = byte;
        checksum_word |= (uint32_t)byte << ((i & 3u) * 8u);
        if ((i & 3u) == 3u) {
            checksum += checksum_word;
            checksum_word = 0u;
        }
    }

    if ((size_bytes & 3u) != 0u) {
        checksum += checksum_word;
    }

    if (checksum != expected_checksum) {
        boot_info[5] = BOOT_STATUS_BAD_CHECKSUM;
        uart_puts("BOOT=ER\n> ");
        return;
    }

    write_boot_info(load_addr, size_bytes, entry_addr, expected_checksum);
    boot_entry_addr = entry_addr;
    boot_loaded = 1u;
    uart_puts("BOOT=OK\n> ");
}

static void run_loaded_program(void)
{
    void (*entry)(void) = (void (*)(void))(uintptr_t)boot_entry_addr;

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
    retry_sd_boot();

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
            case 'i':
                show_boot_info();
                break;
            case 'm':
                dump_memory_snapshot();
                break;
            case 't':
                show_time_snapshot();
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
