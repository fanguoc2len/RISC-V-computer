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

#define REG32(addr) (*(volatile uint32_t *)(addr))

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

#define PS2_DATA         REG32(PS2_BASE + 0x00u)
#define PS2_STATUS       REG32(PS2_BASE + 0x04u)

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

#endif
