# Architecture

## 1. Muc tieu thuc te

Do an nay can ra duoc mot he thong chay that tren FPGA, vi vay kien truc nen uu tien:

- it clock domain
- mot bus protocol nhe, de kiem chung
- debug duoc bang UART va LED
- mo rong duoc tung khoi

He thong hien tai su dung **AXI4-Lite 32-bit** giua PicoRV32 va address
decoder. Cau hinh mac dinh la `USE_AXI=1`; co the dat `USE_AXI=0` de quay lai
native memory interface khi can so sanh timing hoac debug.

AXI4-Lite phu hop hon AXI4 day du trong giai doan nay vi:

- chi co 1 master la CPU
- moi lenh/load/store la mot transfer 32-bit, khong can burst
- co handshake va backpressure doc lap cho tung channel
- de ket noi voi AXI interconnect/IP cua Vivado sau nay
- van giu duoc memory map va peripheral native hien co qua bridge

## 2. So do khoi

```text
                +----------------------+
clk/reset ----->|      PicoRV32        |
                | AXI4-Lite master     |
                +----------+-----------+
                           |
                 +---------+----------+
                 | AXI4-Lite -> native|
                 | single outstanding |
                 +---------+----------+
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

Timer `irq[3]` enters the CPU at ROM vector `0x0000_0010`. The generated
handler preserves `t0/t1` in PicoRV32 q-registers, clears the level source,
and returns with `retirq`; details are in `INTERRUPTS.md`.

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
- noi dung sau power-up khong duoc software xem la gia tri khoi tao; bootloader
  phai ghi metadata, payload va scratch word truoc khi doc
- dung cho:
  - stack
  - data
  - chuong trinh da duoc bootloader load vao
  - sau nay co the tach them vung text VRAM neu can

Khong nen lam framebuffer do hoa full-color o giai doan dau, vi se ton rat nhieu BRAM. Thay vao do, VGA nen di theo huong **text mode**.

Vong lap zero-fill SRAM va space-fill text RAM chi duoc bat trong RTL
simulation. Khi synthesis, SRAM duoc suy dien thanh block RAM khong phu thuoc
power-up value; text console tu xoa toan bo RAM bang `clear_active` sau reset.
Boot ROM van nap `bootrom.mem` trong ca simulation va synthesis. CI prefill
toan bo SRAM bang mau khac zero truoc khi nha reset de bat moi phu thuoc ngam
vao gia tri power-up.

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

- `board_clk = 100 MHz` tu oscillator cua Basys 3
- `soc_clk = 50 MHz` tao bang chia 2, dung cho CPU, AXI, RAM va peripheral
- `pixel_clk = 25 MHz` tao bang chia 4, dung cho VGA

Hai clock chia duoc khai bao bang `create_generated_clock` trong XDC. Muc
50 MHz giup datapath NPU/PCPI dat timing tren `xc7a35t-1`; tham so UART cung
duoc tinh theo 50 MHz.

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

- AXI4 crossbar nhieu master/slave, burst va cache day du
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
