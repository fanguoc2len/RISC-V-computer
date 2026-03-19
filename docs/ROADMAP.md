# Roadmap

## Phase 1 - Nen toi thieu chay duoc

Muc tieu:

- PicoRV32 chay tren Basys 3
- reset, LED, UART, SRAM on dinh
- co banner boot qua UART

Deliverables:

- bitstream synthesize duoc
- boot ROM source
- memory map ro rang

## Phase 2 - Bootloader tu storage

Muc tieu:

- SPI master chay on
- SD card vao SPI mode
- doc duoc sector
- load image vao SRAM

Deliverables:

- boot image raw
- checksum check
- jump vao application

## Phase 3 - VGA output

Muc tieu:

- VGA timing 640x480@60Hz
- test pattern
- sau do text mode co ban

Deliverables:

- man hinh hien thong tin boot
- console text don gian

## Phase 4 - Keyboard input

Muc tieu:

- doc scan code tu PS/2
- echo qua UART
- convert mot phan thanh ASCII

Deliverables:

- terminal co input tu keyboard

## Phase 5 - Mini monitor / simple apps

Muc tieu:

- shell don gian
- chay mot vai program nho
- co the demo "PC toi gian"

Deliverables:

- hello app
- memory test
- keyboard echo

## Phase 6 - Tuy chon nang cap

Chi lam neu con thoi gian:

- IRQ
- text VRAM dep hon
- simple file system
- game / calculator / text editor sieu don gian

## Uu tien quan trong

Thu tu uu tien nen la:

1. he thong chay on dinh
2. boot duoc
3. debug duoc
4. hien thi duoc
5. input duoc
6. dep va nhieu tinh nang sau
