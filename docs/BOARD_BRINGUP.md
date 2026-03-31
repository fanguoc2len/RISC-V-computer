# Board Bring-up

Tai lieu nay dung cho moc tiep theo sau khi `top_basys3_tb` da pass behavioral simulation trong Vivado.

Neu ban chua co board that, van nen doc tai lieu nay de biet cac dau hieu song can dat. Khi do, `top_basys3_tb` chinh la moc xac nhan dau tien thay cho phan cung.

Muc tieu cua buoc bring-up dau tien:

1. synthesize va route thanh cong
2. nap duoc bitstream vao Basys 3
3. nhin thay 3 dau hieu song co ban:
   - `LED0` sang
   - UART hien banner monitor va prompt
   - VGA len text console

## 1. Build bitstream

Mo Windows `CMD` tai thu muc repo va chay:

```bat
scripts\run_vivado_build.bat
```

Neu dang mo Vivado GUI va muon giu cua so mo de xem report/nghia cua slack sau khi build xong, dung:

```tcl
source E:/RISC-V-computer-main/RISC-V-computer-main/scripts/run_vivado_build_gui.tcl
```

Script nay se:

- tao lai project Vivado
- run `synth_1`
- run `impl_1` den `write_bitstream`
- uu tien strategy thien ve timing cho `synth_1` va `impl_1`
- ghi report timing va utilization vao thu muc `build`
- ghi them `build\build_status.txt` de tom tat `synth_status`, `impl_status`, `synth_strategy`, `impl_strategy`, `worst_setup_slack_ns`, `worst_hold_slack_ns`

File can kiem tra sau khi build:

- `build\vivado_build.log`
- `build\build_status.txt`
- `build\timing_summary_post_route.rpt`
- `build\utilization_post_route.rpt`
- `build\vivado\risc_v_computer.runs\impl_1\top_basys3.bit`

Neu build loi, doc `vivado_build.log` truoc tien.
Neu build xong nhung `worst_setup_slack_ns < 0`, van co the nap board de bring-up som, nhung can coi do la canh bao timing.

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
3. cho phep lenh `l` toggle `LED0`, lenh `b` validate header boot image `RVPC` qua SPI, lenh `k` kiem tra PS/2, lenh `x` test matvec4 qua NPU, va lenh `g` jump vao app `RVOS/32` trong SRAM, trong khi khoi `VGA` hien lai lich su text shell

Ban nen thay:

- `LED0` sang on dinh
- cong serial hien banner va prompt `> `
- man hinh VGA co text console va dong footer `LED/TIME/PS2/STAT`
- gui `l` qua UART thi `LED0` doi trang thai
- gui `b` qua UART thi monitor bao `BOOT=OK`
- gui `k` qua UART thi monitor bao `PS2=OK RAW=.. ASCII=..`
- gui `i` qua UART thi monitor bao `BOOTLD=1 ENTRY=10000020 STATUS=00000001`
- dong footer `STAT` tren VGA hien `00000001` sau khi autoboot thanh cong
- gui `m` qua UART thi monitor in `BI0=` va `APP0=`
- gui `t` qua UART thi monitor in `TIME=`
- gui `r` qua UART thi monitor in `RAM=OK`
- gui `n` qua UART thi monitor in `NPU=OK RES=00000032`
- gui `p` qua UART thi monitor in `PCPI=OK RES=00000032`
- gui `v` qua UART thi monitor in `V16=OK MMIO=FFFFFF5C PCPI=FFFFFF5C`
- gui `x` qua UART thi monitor in `MAT=OK R0=00000032 R1=FFFFFFFC R2=FFFFFFCE R3=000000E2`
- gui `g` qua UART thi app `RVOS/32` trong SRAM chay, doi `LED[3:0]` thanh `0xA`, in `RVOS/32`, va cho prompt `APP> `
- trong app `RVOS/32`, gui `h` se in `APPCMDS:H C I L T N V Q`, gui `n` se in `APPNPU=OK`, gui `v` se in `APPMAT=OK`, va gui `q` se return ve monitor bang `GO=RET`
- gui phim `H` tu PS/2 thi monitor co the tra lai help `CMDS:`
- gui phim `A` tu PS/2 thi monitor echo `a`, sau do tra `?` neu ky tu do chua map thanh lenh

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

Trong ban hien tai, VGA text console duoc feed truc tiep tu stream UART debug trong SoC. Neu UART song ma VGA den, kha nang cao la loi o timing/pin/man hinh; neu VGA co len nhung khong hien text moi, kiem tra them duong `debug_uart_tx_valid/debug_uart_tx_char`.
Neu VGA co len nhung dong `STAT` khong phai `00000001`, uu tien kiem tra lai duong boot SPI/boot image.

## 6. Neu bitstream nap duoc nhung khong co dau hieu song

Check theo thu tu nay:

1. `btnC` co dang giu reset khong
2. clock `100 MHz` cua Basys 3 da constraint dung chua
3. `bootrom.mem` co duoc add vao project khong
4. `LED0` co thuc su noi vao `gpio_out[0]` khong
5. top implementation co phai la `top_basys3` khong
6. `build\build_status.txt` co bao bitstream ton tai va timing hop le khong

## 7. Moc tiep theo nen lam

Sau khi board bring-up thanh cong, thu tu nen di tiep la:

1. giu `UART + SRAM + GPIO` that on dinh
2. lam monitor shell nho qua UART
3. giu `VGA text console + PS/2` on dinh tren board
4. sau do moi nang cap app/NPU theo huong mini-PC hon

Day la duong di an toan nhat cho do an 6 thang, vi moi moc deu co cach test ro rang tren phan cung that.

Neu chua co board, dung phien ban mo phong tuong ung:

1. smoke sim xac nhan banner `RV32`, reply `CMDS:`, reply `LED=0`, reply `BOOT=OK`, reply `PS2=OK`, `STATUS=00000001`, `RAM=OK`, `NPU=OK`, `PCPI=OK`, `V16=OK`, `MAT=OK`, UART marker `G` tu SRAM app, `HSYNC`, va text trong `VGA text console`
2. chay `scripts\run_vivado_monitor_sim.bat` hoac `scripts/run_vivado_monitor_sim_gui.tcl` de iterate nhanh phan monitor shell UART/SPI/PS2
3. them testbench cho bootloader SPI/SD o muc protocol don gian
4. chi can hardware that o giai doan cuoi de xac nhan pinout va timing thuc te
