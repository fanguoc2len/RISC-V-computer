# Architecture

## 1. Muc tieu thuc te

Do an nay can ra duoc mot he thong chay that tren FPGA, vi vay kien truc nen uu tien:

- it clock domain
- it bus protocol
- debug duoc bang UART va LED
- mo rong duoc tung khoi

Thay vi bat dau bang AXI/Wishbone day du, giai doan 1 su dung **native memory interface** cua PicoRV32. Day la lua chon rat hop ly cho do an sinh vien vi:

- chi co 1 master la CPU
- memory map rat de debug
- co the chen peripheral bang decoder don gian
- de chuyen sang bus chuan hon sau nay neu can

## 2. So do khoi

```text
                +----------------------+
clk/reset ----->|      PicoRV32        |
                | native mem interface |
                +----------+-----------+
                           |
                  +--------+--------+
                  | address decoder |
                  +---+---+---+---+-+
                      |   |   |   |
                      |   |   |   +------ PS/2 keyboard MMIO
                      |   |   +---------- SPI master MMIO
                      |   +-------------- timer / GPIO / UART MMIO
                      +------------------ BRAM ROM + BRAM SRAM

clk/4 --------------------------------> VGA timing + test pattern
```

## 3. Memory organization

### Boot ROM

- dat tai `0x0000_0000`
- kich thuoc de xuat: `16 KB`
- chua reset handler va bootloader rat gon
- muc tieu:
  - init UART
  - in banner he thong
  - init SPI/SD
  - load image vao SRAM
  - nhay vao entry point cua image

### Unified SRAM

- dat tai `0x1000_0000`
- kich thuoc de xuat giai doan dau: `64 KB`
- dung cho:
  - stack
  - data
  - chuong trinh da duoc bootloader load vao
  - sau nay co the tach them vung text VRAM neu can

Khong nen lam framebuffer do hoa full-color o giai doan dau, vi se ton rat nhieu BRAM. Thay vao do, VGA nen di theo huong **text mode**.

## 4. I/O strategy

### UART

UART la cong cu debug quan trong nhat. Moi moc phat trien deu nen co thong diep UART:

- reset xong
- SRAM ok
- SD init ok / fail
- keyboard event
- jump vao program

### VGA

Giai doan 1 chi can **test pattern** de xac nhan timing va output.

Giai doan 2 moi chuyen sang **text mode**:

- char ROM
- text VRAM
- cursor
- co the hien thi terminal don gian

### PS/2 keyboard

Khong nen parse full keyboard stack ngay. Chi can:

- doc scan code
- dua scan code ve UART
- sau do moi map thanh ASCII cho terminal

### SPI + SD card

Giai doan dau chi nen dung **SPI mode** cua SD card, vi de implement hon SD native mode.

Tranh FAT32 trong milestone dau. Giai phap gon va thuc te:

- dat boot image vao sector co dinh
- doc custom header
- copy payload vao SRAM
- kiem checksum
- jump

## 5. Clocking

- `sys_clk = 100 MHz` (Basys 3)
- `pixel_clk = 25 MHz` tao bang chia 4 tu `sys_clk`

Neu text mode va CPU deu chay on o 100 MHz thi chua can PLL/MMCM ngay.

## 6. Boot philosophy

Boot flow don gian nen la:

1. CPU reset vao boot ROM
2. UART in banner
3. Thu load image tu SD card qua SPI
4. Neu thanh cong: jump vao SRAM
5. Neu that bai: vao monitor qua UART

Dieu nay giong mot personal computer toi gian hon la viec hard-code mot program duy nhat vao ROM.

## 7. Vi sao khong nen lam qua phuc tap som

Nhung huong sau nghe hay nhung rat de qua tai cho do an 6 thang:

- AXI crossbar day du
- DDR controller tu viet
- FAT32 + file browser + shell day du ngay tu dau
- framebuffer VGA do hoa lon
- multitasking/OS som

Huong thuc te hon:

- BRAM truoc
- monitor shell truoc
- text mode truoc
- raw boot image truoc

## 8. Muc tieu chot cho bao ve

Neu he thong cua ban lam duoc cac diem sau thi da rat manh cho mot do an tot nghiep:

- boot on FPGA that
- in thong tin he thong qua UART
- hien thi man hinh text mode qua VGA
- nhan input tu keyboard/UART
- load va chay it nhat 1 program tu SD card

Day la mot mini personal computer thuc su, du kich thuoc nho.
