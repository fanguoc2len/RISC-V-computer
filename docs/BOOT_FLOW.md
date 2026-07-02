# Boot Flow

## Muc tieu

Xay dung bootloader **de lam duoc tren FPGA va trong khung do an 6 thang**.

Vi vay, boot flow duoc de xuat la:

1. reset vao Boot ROM
2. init UART
3. in banner
4. auto-thu boot image tu storage
5. neu fail thi fallback ve monitor shell
6. neu can thi retry boot bang lenh UART
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

- lenh `b` trong monitor shell doc header `RVPC` mau qua SPI model
- ngay sau reset, monitor cung auto-thu boot image mot lan
- SPI model hien tai tra du lieu theo block `CMD17`-like:
  - host gui `6-byte read command`
  - storage tra `R1=0x00`
  - sau do tra `0xFE + 512 data bytes + 2 CRC bytes`
- sector 0 chua header 32 byte va padding zero, sector 1+ chua payload va padding zero
- Boot ROM parse duoc `load_addr`, `size_bytes`, `entry_addr` thay vi hardcode dia chi SRAM
- Boot ROM tinh checksum payload trong luc copy va so sanh voi field `checksum` trong header
- smoke sim co y dat `load_addr = entry_addr = 0x1000_0020` de chung minh logic parse header dang duoc dung that
- testbench tra ve `BOOT=OK` neu header hop le
- payload mau duoc copy vao SRAM theo `load_addr`
- Boot ROM ghi `boot info block` vao dau SRAM de app biet no duoc load nhu the nao
- lenh `g` jump vao `entry_addr` va app doc lai `boot info block` truoc khi phat marker `I` va `G` qua UART

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
- `i`: in boot state hien tai (`boot_loaded`, `entry`)
- `m`: dump nhanh `boot info block` va word dau cua app trong SRAM
- `t`: doc timer counter de kiem tra peripheral timer/MMIO dang song
- cho lenh don gian:
  - `h`: help
  - `k`: doc keyboard status
  - `b`: retry boot

Nhu vay luc demo, du SD card co loi ban van con duong de debug.

Ngoai UART monitor, milestone hien tai cung da co VGA status panel don gian:

- hien `LED`
- hien `TIME`
- hien byte `PS2` gan nhat
- van giu nen color bars de debug timing/man hinh nhanh

## Goi y milestone

1. `UART banner`
2. `SPI loopback/test transfer`
3. `SD init`
4. `read sector 0`
5. `load raw image`
6. `jump vao SRAM`
