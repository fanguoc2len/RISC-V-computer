# Boot ROM Firmware

Day la source cho boot ROM cua he thong.

Muc tieu firmware:

1. in banner qua UART
2. hien thong tin he thong
3. thu boot image tu SD card
4. fallback ve monitor shell neu boot fail

Hien tai file `bootrom.mem` o root repo la **monitor image** de Vivado synthesize/simulate duoc ngay, khong can RISC-V toolchain:

- in banner `RV32 PC`
- auto-thu boot image qua SPI ngay sau reset
- hien prompt UART
- nhan lenh `h` de in help
- nhan lenh `c` de clear text console va in prompt moi
- nhan lenh `l` de toggle `LED0`
- nhan lenh `b` de validate header raw boot image `RVPC`
- nhan lenh `k` de hien `last_ps2_raw/last_ps2_ascii`
- nhan lenh `i` de in thong tin boot hien tai
- nhan lenh `m` de dump nhanh `boot info block` va word dau cua app trong SRAM
- nhan lenh `t` de doc timer counter qua MMIO
- nhan lenh `r` de tu test mot vung SRAM scratch va tra `RAM=OK`
- nhan lenh `n` de goi MMIO NPU-lite dot4 int8 va tra `NPU=OK RES=00000032`
- nhan lenh `p` de goi custom instruction qua PCPI va tra `PCPI=OK RES=00000032`
- nhan lenh `v` de chay 4 lan dot4 tich luy thanh vector-16 va tra `V16=OK MMIO=FFFFFF5C PCPI=FFFFFF5C`
- nhan lenh `x` de chay matvec4 int8 trong NPU MMIO va tra `MAT=OK R0=... R1=... R2=... R3=...`
- nhan lenh `g` de jump vao app `RVOS/32` da load trong SRAM
- co the dung mot nhom phim PS/2 (`h c l b k i m t r n p v x g`) de kich lai truc tiep cac lenh monitor qua keyboard
- ky tu PS/2 decode duoc nhu `a` cung di vao shell input path, duoc echo ra UART, va neu chua map thanh lenh thi monitor tra `?`
- khi boot thanh cong, Boot ROM ghi `boot info block` vao dau SRAM de app mau co the doc lai thong tin image
- app `RVOS/32` hien `APP> ` va co nhom lenh `H C I L T N V Q`; lenh `q` return ve monitor bang `GO=RET`

Ban co 2 duong de tiep tuc:

1. dung `scripts/gen_bootrom.py` / `scripts\gen_bootrom.bat` de regenerate monitor image nhanh
   script nay cap nhat ca `bootrom.mem` va `boot_image.hex` cho simulation SPI boot
2. khi co RISC-V toolchain, build lai tu source trong thu muc nay va thay `bootrom.mem` bang bootloader that
