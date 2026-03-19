TOOLCHAIN_PREFIX ?= riscv64-unknown-elf-

CC      := $(TOOLCHAIN_PREFIX)gcc
OBJCOPY := $(TOOLCHAIN_PREFIX)objcopy

CFLAGS  := -march=rv32imc -mabi=ilp32 -Os -ffreestanding -nostdlib -Wall -Wextra
LDFLAGS := -T linker.ld -nostdlib -Wl,-Map=bootrom.map

OBJS := start.o bootrom.o

all: bootrom.elf

bootrom.elf: $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)

start.o: start.S
	$(CC) $(CFLAGS) -c -o $@ $<

bootrom.o: bootrom.c platform.h
	$(CC) $(CFLAGS) -c -o $@ bootrom.c

bootrom.bin: bootrom.elf
	$(OBJCOPY) -O binary $< $@

clean:
	rm -f $(OBJS) bootrom.elf bootrom.bin bootrom.map
