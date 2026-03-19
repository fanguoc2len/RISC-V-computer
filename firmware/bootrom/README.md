# Boot ROM Firmware

Day la source cho boot ROM cua he thong.

Muc tieu firmware:

1. in banner qua UART
2. hien thong tin he thong
3. thu boot image tu SD card
4. fallback ve monitor shell neu boot fail

Hien tai file `bootrom.mem` o root repo la **smoke-test image** de Vivado synthesize/simulate duoc ngay:

- bat `LED0`
- gui 1 byte UART
- sau do loop vo han

Khi ban co RISC-V toolchain, hay build lai tu source trong thu muc nay va thay `bootrom.mem` bang bootloader that.
