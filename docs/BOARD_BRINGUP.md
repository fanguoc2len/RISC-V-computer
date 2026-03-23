# Board Bring-up

Tai lieu nay dung cho moc tiep theo sau khi `top_basys3_tb` da pass behavioral simulation trong Vivado.

Neu ban chua co board that, van nen doc tai lieu nay de biet cac dau hieu song can dat. Khi do, `top_basys3_tb` chinh la moc xac nhan dau tien thay cho phan cung.

Muc tieu cua buoc bring-up dau tien:

1. synthesize va route thanh cong
2. nap duoc bitstream vao Basys 3
3. nhin thay 3 dau hieu song co ban:
   - `LED0` sang
   - UART hien banner monitor va prompt
   - VGA len test pattern

## 1. Build bitstream

Mo Windows `CMD` tai thu muc repo va chay:

```bat
scripts\run_vivado_build.bat
```

Script nay se:

- tao lai project Vivado
- run `synth_1`
- run `impl_1` den `write_bitstream`
- ghi report timing va utilization vao thu muc `build`

File can kiem tra sau khi build:

- `build\vivado_build.log`
- `build\timing_summary_post_route.rpt`
- `build\utilization_post_route.rpt`
- `build\vivado\risc_v_computer.runs\impl_1\top_basys3.bit`

Neu build loi, doc `vivado_build.log` truoc tien.

## 2. Nap board

Ket noi Basys 3 qua USB/JTAG, cap nguon, roi chay:

```bat
scripts\program_basys3.bat
```

Script nay se:

- mo hardware manager
- ket noi `hw_server`
- tim FPGA dau tien
- nap `top_basys3.bit`

Neu script bao khong tim thay hardware:

- kiem tra cap USB
- kiem tra driver Digilent
- dam bao board da bat nguon
- dam bao khong co phien Vivado khac dang giu hardware manager

## 3. Dau hieu dung tren board

Voi ban bring-up hien tai, boot ROM monitor image se lam 3 viec:

1. ghi `GPIO` de bat `LED0`
2. in banner monitor va cho lenh UART
3. cho phep lenh `l` toggle `LED0`, lenh `b` chay SPI smoke transfer, va lenh `k` kiem tra PS/2, trong khi khoi `VGA` van phat test pattern

Ban nen thay:

- `LED0` sang on dinh
- cong serial hien banner va prompt `> `
- man hinh VGA co hinh mau test pattern
- gui `l` qua UART thi `LED0` doi trang thai
- gui `b` qua UART thi monitor bao `SPI=OK`
- gui `k` qua UART thi monitor bao `PS2=OK`

Thong so UART:

- `115200`
- `8 data bits`
- `no parity`
- `1 stop bit`

## 4. Neu LED sang nhung UART im

Uu tien kiem tra:

- cong COM dang dung co dung khong
- terminal da dat `115200 8N1` chua
- pin `RsTx` trong `constraints/basys3_top.xdc` da dung chua

Neu can, dung oscilloscope/logic analyzer do truc tiep chan UART TX.

## 5. Neu UART co du lieu nhung VGA den

Uu tien kiem tra:

- man hinh co ho tro `640x480@60Hz` khong
- cap VGA co tot khong
- `Hsync/Vsync` co dao khong
- cac chan `vgaRed/Green/Blue` trong `.xdc` da dung chua

Trong ban hien tai, VGA khong phu thuoc vao firmware phuc tap. Neu UART song ma VGA den, kha nang cao la loi o timing/pin/man hinh.

## 6. Neu bitstream nap duoc nhung khong co dau hieu song

Check theo thu tu nay:

1. `btnC` co dang giu reset khong
2. clock `100 MHz` cua Basys 3 da constraint dung chua
3. `bootrom.mem` co duoc add vao project khong
4. `LED0` co thuc su noi vao `gpio_out[0]` khong
5. top implementation co phai la `top_basys3` khong

## 7. Moc tiep theo nen lam

Sau khi board bring-up thanh cong, thu tu nen di tiep la:

1. giu `UART + SRAM + GPIO` that on dinh
2. lam monitor shell nho qua UART
3. sau do moi them `SPI/SD bootloader`
4. cuoi cung moi nang cap `VGA` sang text mode va them `PS/2`

Day la duong di an toan nhat cho do an 6 thang, vi moi moc deu co cach test ro rang tren phan cung that.

Neu chua co board, dung phien ban mo phong tuong ung:

1. smoke sim xac nhan banner `RV32`, reply `CMDS:`, reply `LED=0`, reply `SPI=OK`, reply `PS2=OK`, va `HSYNC`
2. them testbench cho monitor shell UART
3. them testbench cho bootloader SPI/SD o muc protocol don gian
4. chi can hardware that o giai doan cuoi de xac nhan pinout va timing thuc te
