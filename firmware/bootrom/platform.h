#ifndef PLATFORM_H
#define PLATFORM_H

#include <stdint.h>

#define SRAM_BASE        0x10000000u
#define SRAM_SIZE_BYTES  0x00010000u

#define UART_BASE        0x20000000u
#define GPIO_BASE        0x20001000u
#define TIMER_BASE       0x20002000u
#define SPI_BASE         0x20003000u
#define PS2_BASE         0x20004000u
#define NPU_BASE         0x20005000u

#define REG32(addr) (*(volatile uint32_t *)(addr))
#define REG8(addr)  (*(volatile uint8_t *)(addr))

#define UART_DIV         REG32(UART_BASE + 0x00u)
#define UART_DATA        REG32(UART_BASE + 0x04u)

#define GPIO_OUT         REG32(GPIO_BASE + 0x00u)

#define TIMER_COUNT_LO   REG32(TIMER_BASE + 0x00u)
#define TIMER_COUNT_HI   REG32(TIMER_BASE + 0x04u)
#define TIMER_CMP_LO     REG32(TIMER_BASE + 0x08u)
#define TIMER_CMP_HI     REG32(TIMER_BASE + 0x0Cu)
#define TIMER_CTRL       REG32(TIMER_BASE + 0x10u)

#define SPI_CTRL         REG32(SPI_BASE + 0x00u)
#define SPI_DATA         REG32(SPI_BASE + 0x04u)
#define SPI_CTRL8        REG8(SPI_BASE + 0x00u)
#define SPI_DATA8        REG8(SPI_BASE + 0x04u)

#define PS2_DATA         REG32(PS2_BASE + 0x00u)
#define PS2_STATUS       REG32(PS2_BASE + 0x04u)

#define NPU_CTRL         REG32(NPU_BASE + 0x00u)
#define NPU_VEC_A        REG32(NPU_BASE + 0x04u)
#define NPU_VEC_B        REG32(NPU_BASE + 0x08u)
#define NPU_RESULT       REG32(NPU_BASE + 0x0Cu)
#define NPU_MAT_ROW1     REG32(NPU_BASE + 0x10u)
#define NPU_MAT_ROW2     REG32(NPU_BASE + 0x14u)
#define NPU_MAT_ROW3     REG32(NPU_BASE + 0x18u)
#define NPU_MAT_RES1     REG32(NPU_BASE + 0x1Cu)
#define NPU_MAT_RES2     REG32(NPU_BASE + 0x20u)
#define NPU_MAT_RES3     REG32(NPU_BASE + 0x24u)

#define NPU_CTRL_START        0x1u
#define NPU_CTRL_CLEAR_DONE   0x2u
#define NPU_CTRL_CLEAR_ACC    0x4u
#define NPU_CTRL_ACCUMULATE   0x8u
#define NPU_CTRL_START_MATVEC 0x10u

static inline void uart_set_divider(uint32_t div)
{
    UART_DIV = div;
}

static inline void uart_putc(char ch)
{
    UART_DATA = (uint32_t)(uint8_t)ch;
}

static inline void uart_puts(const char *s)
{
    while (*s) {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s++);
    }
}

static inline int uart_try_getc(void)
{
    uint32_t value = UART_DATA;
    if (value == 0xFFFFFFFFu) {
        return -1;
    }
    return (int)(value & 0xFFu);
}

static inline void gpio_write(uint32_t value)
{
    GPIO_OUT = value;
}

static inline void spi_set_divider(uint16_t div)
{
    REG8(SPI_BASE + 2u) = (uint8_t)(div & 0xFFu);
    REG8(SPI_BASE + 3u) = (uint8_t)(div >> 8);
}

static inline void spi_cs_assert(void)
{
    SPI_CTRL8 = 0x0Au;
}

static inline void spi_cs_release(void)
{
    SPI_CTRL8 = 0x08u;
}

static inline uint8_t spi_transfer_byte_hold(uint8_t tx)
{
    SPI_DATA8 = tx;
    SPI_CTRL8 = 0x0Bu;

    while (SPI_CTRL & (1u << 2)) {
    }

    tx = SPI_DATA8;
    SPI_CTRL8 = 0x0Au;
    return tx;
}

static inline uint8_t spi_transfer_byte(uint8_t tx)
{
    spi_cs_assert();
    tx = spi_transfer_byte_hold(tx);
    spi_cs_release();
    return tx;
}

static inline void npu_start(void)
{
    NPU_CTRL = NPU_CTRL_START;
}

static inline uint32_t npu_status(void)
{
    return NPU_CTRL;
}

static inline void npu_clear_done(void)
{
    NPU_CTRL = NPU_CTRL_CLEAR_DONE;
}

static inline void npu_clear_accumulator(void)
{
    NPU_CTRL = NPU_CTRL_CLEAR_ACC | NPU_CTRL_CLEAR_DONE;
}

static inline void npu_start_accum(void)
{
    NPU_CTRL = NPU_CTRL_START | NPU_CTRL_ACCUMULATE;
}

static inline void npu_start_matvec(void)
{
    NPU_CTRL = NPU_CTRL_START_MATVEC;
}

static inline int32_t npu_dot4_pcpi(uint32_t vec_a, uint32_t vec_b)
{
    int32_t result;
    asm volatile(".insn r 0x0b, 0, 0x2a, %0, %1, %2"
                 : "=r"(result)
                 : "r"(vec_a), "r"(vec_b));
    return result;
}

#endif
