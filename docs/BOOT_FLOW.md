# Boot Flow

## Muc tieu

Xay dung bootloader **de lam duoc tren FPGA va trong khung do an 6 thang**.

Vi vay, boot flow duoc de xuat la:

1. reset vao Boot ROM
2. init UART
3. in banner
4. init SPI
5. doc boot image tu SD card
6. copy vao SRAM
7. jump vao entry point

## Tai sao khong nen FAT32 ngay

FAT32 nghe "giong PC" hon, nhung trong giai doan dau no tang rat nhieu do phuc tap:

- parser MBR/partition
- parser FAT
- parser directory
- xu ly cluster chain
- debug kho

Cho milestone dau, nen dung **raw image format** tai sector co dinh.

## De xuat boot image format

Header 32 byte tai sector bat dau:

```c
struct boot_image_header {
    uint32_t magic;       // 'RVPC'
    uint32_t load_addr;   // vd 0x10000000
    uint32_t size_bytes;  // kich thuoc payload
    uint32_t entry_addr;  // dia chi jump sau khi load
    uint32_t checksum;    // tong 32-bit hoac CRC32
    uint32_t version;
    uint32_t reserved0;
    uint32_t reserved1;
};
```

Payload nam ngay sau header.

Repo cung cap script de pack raw image:

```text
scripts/gen_raw_boot_image.py
scripts/gen_raw_boot_image.bat
```

Xem them [Boot Image Format](BOOT_IMAGE_FORMAT.md).

## Quy trinh Boot ROM

### Buoc 1: bring-up co ban

- tat LED
- set baud UART
- in:
  - ten he thong
  - CPU
  - kich thuoc SRAM
  - trang thai boot source

### Buoc 2: init SD card qua SPI

Chi can dat muc tieu:

- vao SPI mode
- gui `CMD0`
- `CMD8`
- `ACMD41`
- `CMD58`
- `CMD17`

Neu lam duoc `CMD17` doc 1 block 512 byte la da du cho boot raw image.

### Buoc 3: doc header

- kiem `magic`
- kiem `load_addr` nam trong SRAM
- kiem `size_bytes` khong vuot RAM
- kiem checksum

Milestone mo phong hien tai da cham duoc buoc nay o muc don gian:

- lenh `b` trong monitor shell doc va validate header `RVPC` mau qua SPI model
- testbench tra ve `BOOT=OK` neu header hop le

### Buoc 4: copy payload

- doc tung block 512 byte
- ghi vao SRAM
- cap nhat checksum

### Buoc 5: jump

- dat stack pointer
- jump `entry_addr`

## Fallback mode

Neu SD boot fail thi khong nen treo im.

Nen vao che do monitor:

- in loi qua UART
- cho lenh don gian:
  - `h`: help
  - `m`: dump thong tin memory
  - `k`: doc keyboard status
  - `b`: retry boot

Nhu vay luc demo, du SD card co loi ban van con duong de debug.

## Goi y milestone

1. `UART banner`
2. `SPI loopback/test transfer`
3. `SD init`
4. `read sector 0`
5. `load raw image`
6. `jump vao SRAM`
