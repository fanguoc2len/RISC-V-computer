# Roadmap

## Current status

Tinh den 2026-07-31, nhanh hien tai da co:

- smoke simulation pass end-to-end tren `top_basys3_tb`
- monitor shell qua UART voi cac lenh `h c l b k i m t r n p v x g`
- bootloader SPI raw image co `header/checksum/jump`
- `boot info block` va `STATUS=00000001` sau khi boot thanh cong
- VGA text console `80x29` + dong footer (`LED`, `TIME`, `PS2`, `STAT`)
- duong PS/2 co xac nhan trong smoke sim
- keyboard PS/2 da decode duoc mot nhom scan code Set 2 sang ASCII va co the kich mot phan lenh monitor
- ky tu PS/2 decode duoc da di vao monitor input path va echo qua UART, khong chi dung cho command hotkey
- lenh `r` da tu test mot vung SRAM scratch va tra `RAM=OK`
- co `NPU-lite` dot4 int8 theo 2 duong: MMIO (`n`) va PCPI/custom instruction (`p`)
- co path vector-16 accumulate (`v`) de doi chieu MMIO va PCPI tren cung bo du lieu
- co path matvec4 int8 (`x`) de vuot khoi muc demo dot4 don le
- co `monitor_shell_tb` de iterate nhanh monitor shell ma khong can full top-level VGA smoke sim
- app `RVOS/32` trong SRAM chay duoc, co marker `I/G`, co prompt `APP> `, va co nhom lenh rieng `h c i l t n v q`
- CPU dung duong AXI4-Lite mac dinh, co native fallback va DECERR observability
- CI open-source kiem tra config drift, boot image, full-top Yosys synthesis
  kem resource ceiling 80%, AXI bridge, timer va hai regression end-to-end
- Vivado 2025.2 da tao bitstream voi setup/hold slack duong va DRC khong co error
- timer IRQ3 da co vector `0x10`, save/restore q2/q3, EOI counter va regression end-to-end

## Trang thai cac phase

- Phase 1: hoan thanh va da synthesize/implement/tao bitstream.
- Phase 2: hoan thanh duong raw-image trong mo phong (header/checksum/load/jump);
  viec xac nhan voi the SD vat ly va filesystem van la nang cap rieng.
- Phase 3: hoan thanh VGA timing, text console va footer.
- Phase 4: hoan thanh PS/2 Set 2 cho nhom phim/lenh demo.
- Phase 5: hoan thanh monitor, SRAM app, RAM self-test va NPU test paths.
- Phase 6: IRQ da hoan thanh; cac muc UI/filesystem/app van la backlog tuy chon.

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
- text console `80x29`
- dong footer status

Deliverables:

- man hinh hien thong tin boot
- console text don gian

## Phase 4 - Keyboard input

Muc tieu:

- doc scan code tu PS/2
- echo qua UART
- convert mot phan thanh ASCII
- kich lai truc tiep mot nhom lenh monitor qua keyboard

Deliverables:

- terminal co input tu keyboard

## Phase 5 - Mini monitor / simple apps

Muc tieu:

- shell don gian
- chay mot vai program nho
- co the demo "PC toi gian"
- accelerator NPU co bai test lon hon dot4

Deliverables:

- hello app
- memory test
- keyboard echo

## Phase 6 - Tuy chon nang cap

Chi lam neu con thoi gian:

- IRQ (da hoan thanh cho timer one-shot)
- text VRAM dep hon
- simple file system
- game / calculator / text editor sieu don gian

Timer IRQ dung external IRQ3, vector ROM `0x10`, q2/q3 de giu `t0/t1`, W1C
nguon level va `retirq`. Regression AXI va native yeu cau CPU acknowledge dung
mot lan cho moi lan boot roi tiep tuc chay monitor va app SRAM.

## Uu tien quan trong

Thu tu uu tien nen la:

1. he thong chay on dinh
2. boot duoc
3. debug duoc
4. hien thi duoc
5. input duoc
6. dep va nhieu tinh nang sau
