# Boot ROM Firmware

Day la source cho boot ROM cua he thong.

Muc tieu firmware:

1. in banner qua UART
2. hien thong tin he thong
3. thu boot image tu SD card
4. fallback ve monitor shell neu boot fail

Hien tai file `bootrom.mem` o root repo la **monitor image** de Vivado synthesize/simulate duoc ngay, khong can RISC-V toolchain:

- in banner `RV32 PC`
- hien prompt UART
- nhan lenh `h` de in help
- nhan lenh `l` de toggle `LED0`
- nhan lenh `b` de validate header raw boot image `RVPC`
- nhan lenh `k` de chay PS/2 smoke check

Ban co 2 duong de tiep tuc:

1. dung `scripts/gen_bootrom.py` / `scripts\gen_bootrom.bat` de regenerate monitor image nhanh
2. khi co RISC-V toolchain, build lai tu source trong thu muc nay va thay `bootrom.mem` bang bootloader that
