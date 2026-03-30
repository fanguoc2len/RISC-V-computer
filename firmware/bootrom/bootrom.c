#include "platform.h"

#define BOOT_INFO_MAGIC 0x49425652u
#define BOOT_INFO_WORDS 8u
#define BOOT_STATUS_OK 0x00000001u
#define BOOT_STATUS_BAD_MAGIC 0x000000E1u
#define BOOT_STATUS_BAD_RANGE 0x000000E2u
#define BOOT_STATUS_BAD_SIZE 0x000000E3u
#define BOOT_STATUS_BAD_ENTRY 0x000000E4u
#define BOOT_STATUS_BAD_CHECKSUM 0x000000E5u
#define RAMTEST_MIN_BASE (SRAM_BASE + 0x00000200u)
#define RAMTEST_LIMIT    (SRAM_BASE + SRAM_SIZE_BYTES - 0x00000200u)
#define RAMTEST_WORDS    4u
#define NPU_DEMO_VEC_A   0xFC03FE01u
#define NPU_DEMO_VEC_B   0xFC05FA07u
#define NPU_DEMO_EXPECT  0x00000032u

static const uint32_t ramtest_patterns[RAMTEST_WORDS] = {
    0x13579BDFu,
    0x2468ACE0u,
    0x0F0F55AAu,
    0xA5A5F00Fu,
};

static uint32_t boot_loaded;
static uint32_t boot_entry_addr;
static uint32_t ps2_break_prefix;
static uint32_t ps2_extended_prefix;

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
    uart_puts("h=help l=led b=boot k=ps2 i=info m=mem t=time r=ram n=npu p=pcpi g=go\n> ");
}

static void show_ps2_status(void)
{
    uint32_t raw = boot_info[6] & 0xFFu;
    uint32_t ascii = boot_info[7] & 0xFFu;
    uint32_t high_nibble = (raw >> 4) & 0xFu;
    uint32_t low_nibble = raw & 0xFu;

    if (raw == 0u) {
        uart_puts("PS2=ER\n> ");
        return;
    }

    uart_puts("PS2=OK RAW=");
    uart_putc((char)(high_nibble < 10u ? ('0' + high_nibble) : ('A' + (high_nibble - 10u))));
    uart_putc((char)(low_nibble < 10u ? ('0' + low_nibble) : ('A' + (low_nibble - 10u))));
    uart_puts(" ASCII=");
    uart_putc(ascii != 0u ? (char)ascii : '?');
    uart_puts("\n> ");
}

static void show_help(void)
{
    uart_puts("CMDS:h l b k i m t r n p g\n> ");
}

static void uart_put_hex32(uint32_t value)
{
    int shift;

    for (shift = 28; shift >= 0; shift -= 4) {
        uint32_t nibble = (value >> (uint32_t)shift) & 0xFu;
        uart_putc((char)(nibble < 10u ? ('0' + nibble) : ('A' + (nibble - 10u))));
    }
}

static char decode_ps2_ascii(uint8_t scan_code)
{
    switch (scan_code) {
    case 0x1Cu: return 'a';
    case 0x32u: return 'b';
    case 0x34u: return 'g';
    case 0x33u: return 'h';
    case 0x43u: return 'i';
    case 0x42u: return 'k';
    case 0x4Bu: return 'l';
    case 0x3Au: return 'm';
    case 0x2Du: return 'r';
    case 0x2Cu: return 't';
    default:    return 0;
    }
}

static void remember_ps2_key(uint8_t raw, char ascii)
{
    boot_info[6] = (uint32_t)raw;
    boot_info[7] = (uint32_t)(uint8_t)ascii;
}

static int poll_ps2_command(void)
{
    uint8_t scan_code;
    char ascii;

    if ((PS2_STATUS & 0x1u) == 0u) {
        return -1;
    }

    scan_code = (uint8_t)(PS2_DATA & 0xFFu);
    if (scan_code == 0xF0u) {
        ps2_break_prefix = 1u;
        return -1;
    }

    if (scan_code == 0xE0u) {
        ps2_extended_prefix = 1u;
        return -1;
    }

    if (ps2_break_prefix || ps2_extended_prefix) {
        ps2_break_prefix = 0u;
        ps2_extended_prefix = 0u;
        return -1;
    }

    ascii = decode_ps2_ascii(scan_code);
    if (ascii == 0) {
        return -1;
    }

    remember_ps2_key(scan_code, ascii);
    return (int)ascii;
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

static void run_ram_test(void)
{
    uint32_t test_base = RAMTEST_MIN_BASE;
    volatile uint32_t *test_words;
    unsigned int i;

    if (boot_loaded) {
        uint32_t image_end = boot_info[1] + boot_info[2];
        uint32_t aligned_end = (image_end + 31u) & ~31u;

        if (aligned_end > test_base) {
            test_base = aligned_end;
        }
    }

    if ((test_base + (RAMTEST_WORDS * sizeof(uint32_t))) > RAMTEST_LIMIT) {
        uart_puts("RAM=ER\n> ");
        return;
    }

    test_words = (volatile uint32_t *)(uintptr_t)test_base;
    for (i = 0; i < RAMTEST_WORDS; ++i) {
        test_words[i] = ramtest_patterns[i];
    }

    for (i = 0; i < RAMTEST_WORDS; ++i) {
        if (test_words[i] != ramtest_patterns[i]) {
            uart_puts("RAM=ER\n> ");
            return;
        }
    }

    uart_puts("RAM=OK\n> ");
}

static void run_npu_mmio_test(void)
{
    NPU_VEC_A = NPU_DEMO_VEC_A;
    NPU_VEC_B = NPU_DEMO_VEC_B;
    npu_start();

    uart_puts((npu_status() & 0x2u) && (NPU_RESULT == NPU_DEMO_EXPECT) ? "NPU=OK RES=" : "NPU=ER RES=");
    uart_put_hex32(NPU_RESULT);
    uart_puts("\n> ");
}

static void run_npu_pcpi_test(void)
{
    uint32_t result = (uint32_t)npu_dot4_pcpi(NPU_DEMO_VEC_A, NPU_DEMO_VEC_B);

    uart_puts(result == NPU_DEMO_EXPECT ? "PCPI=OK RES=" : "PCPI=ER RES=");
    uart_put_hex32(result);
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
        if (ch < 0) {
            ch = poll_ps2_command();
        }

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
            case 'r':
                run_ram_test();
                break;
            case 'n':
                run_npu_mmio_test();
                break;
            case 'p':
                run_npu_pcpi_test();
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
