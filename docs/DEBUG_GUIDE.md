# Debug Guide

## 1. CPU dung im ngay sau reset

Kiem tra:

- `resetn` da dao dung chua
- `PROGADDR_RESET` da tro vao vung ROM hop le chua
- `bootrom.mem` co duoc load khong
- `mem_ready` co bao gio len khong

Neu `mem_valid` len nhung `mem_ready` khong len, CPU se treo vinh vien o transaction dau tien.

## 2. Doc/ghi RAM sai

Kiem tra:

- address word-aligned chua
- `mem_wstrb` xu ly byte-enable dung chua
- SRAM dung synchronous read hay asynchronous read

Loi rat hay gap la quen tinh **1 cycle latency** cua BRAM.

## 3. UART khong ra ky tu

Kiem tra:

- `clk_freq / baud` da dung chua
- pin `RsTx/RsRx` da constraint dung chua
- terminal dang de `115200 8N1` chua

Ban nen test bang chuoi rat ngan truoc, vi du:

```text
BOOT
```

## 4. VGA khong len hinh

Kiem tra:

- pixel clock co dung ~25 MHz khong
- sync polarity dung 640x480@60Hz chua
- constraint VGA pins co dung board chua

Buoc debug hay nhat:

1. test pattern mau co dinh
2. test border
3. test text mode sau

## 5. PS/2 doc du lieu loi

Kiem tra:

- co bat `PULLUP true` cho `PS2Clk/PS2Data` chua
- bat dau bang viec in raw scan code ra UART
- dong bo input vao system clock truoc khi detect edge

## 6. SPI/SD khong init duoc

Kiem tra:

- SD card dang o 3.3V
- clock init chay cham
- CS giu high/low dung luc
- `CMD0/CMD8/ACMD41` dung thu tu

Dung debug UART de in tung response byte tu SD card. Neu khong in ra, ban se rat kho biet dang sai o dau.

## 7. Loi kien truc thuong gap

Nhung loi hay gay mat thoi gian nhat:

- muon lam qua nhieu IP ngay tu dau
- doi sang DDR qua som
- framebuffer qua lon
- filesystem qua som

Neu bi tac, hay quay lai moc nho nhat:

- UART co song khong
- CPU co fetch ROM khong
- RAM co doc/ghi duoc khong
- 1 peripheral don le co tuong tac duoc khong
