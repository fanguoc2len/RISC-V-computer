# Boot Image Format

Tai lieu nay dong bang dinh dang raw image de Boot ROM co the doc tu storage ma khong can FAT32.

## Header

Header chiem `32 bytes` o dau file:

```c
struct boot_image_header {
    uint32_t magic;       // 'RVPC'
    uint32_t load_addr;   // thuong la 0x10000000
    uint32_t size_bytes;  // kich thuoc payload binary
    uint32_t entry_addr;  // dia chi nhay sau khi load
    uint32_t checksum;    // tong 32-bit little-endian cua payload
    uint32_t version;     // hien tai dung 1
    uint32_t reserved0;
    uint32_t reserved1;
};
```

## Payload

Payload nam ngay sau header, khong nen them parser phuc tap o milestone dau.

Boot ROM chi can:

1. doc header
2. kiem `magic`
3. kiem `load_addr` va `size_bytes` nam trong SRAM
4. copy payload vao RAM
5. tinh lai `checksum`
6. jump `entry_addr`

## Checksum

Checksum duoc tinh bang:

- cat payload thanh cac word `32-bit little-endian`
- neu payload khong chia het cho 4 byte thi pad zero o cuoi
- cong modulo `2^32`

Day la checksum rat de implement trong Boot ROM va du cho milestone sinh vien.

## Generator Script

Repo da co script:

```bat
scripts\gen_raw_boot_image.bat payload.bin output.img --load-addr 0x10000000
```

Hoac tren WSL/Linux:

```bash
python3 scripts/gen_raw_boot_image.py payload.bin output.img --load-addr 0x10000000
```

Vi du:

```bash
python3 scripts/gen_raw_boot_image.py firmware.bin build/app_rvpc.img --load-addr 0x10000000 --entry-addr 0x10000000
```

## Muc tieu milestone

Moc tiep theo cua project la:

1. tao duoc file `.img` theo format nay
2. Boot ROM doc duoc header qua SPI
3. Boot ROM copy duoc payload vao SRAM
4. CPU jump duoc vao `entry_addr`

Lam den day la da co duong boot thuc te, de nang cap thanh mot mini computer chay chuong trinh tu storage.
