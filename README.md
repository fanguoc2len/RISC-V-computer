# RISC-V Computer on FPGA

Starter repository cho do an tot nghiep: xay dung mot may tinh toi gian tren FPGA dua tren `PicoRV32`.

Muc tieu cua repo nay khong phai la nhay thang vao mot he thong qua lon, ma la tao mot duong di thuc te, co the synthesize va debug tung buoc tren FPGA trong khoang 6 thang:

1. `PicoRV32 + BRAM + UART + LED + timer`
2. `SPI + SD bootloader`
3. `VGA text mode`
4. `PS/2 keyboard`
5. `monitor shell` va cac chuong trinh don gian

## Kien truc du kien

- CPU: `PicoRV32` native memory interface
- FPGA target hien tai: `Basys 3 (xc7a35tcpg236-1)`
- Memory model: unified address space
- ROM: boot ROM trong BRAM
- RAM: scratchpad/unified SRAM trong BRAM
- I/O map:
  - `UART`
  - `GPIO/LED`
  - `timer`
  - `SPI master`
  - `PS/2 keyboard`
  - `VGA bring-up`

Lua chon quan trong: repo nay uu tien bus native cua PicoRV32 thay vi AXI/Wishbone trong giai doan dau. Ly do la do an chi co 1 master, can debug nhanh, va can tap trung vao boot/display/input truoc khi tang do phuc tap.

## Cau truc repo

- `rtl/top/top_basys3.v`: top-level cho Basys 3
- `rtl/soc/riscv_pc_soc.v`: SoC chinh
- `rtl/memory/`: ROM va SRAM
- `rtl/peripherals/`: UART/GPIO/timer/SPI/PS2
- `rtl/video/`: VGA timing va test pattern
- `firmware/bootrom/`: source boot ROM
- `constraints/basys3_top.xdc`: pin constraint cho Basys 3
- `scripts/create_vivado_project.tcl`: tao project Vivado nhanh
- `docs/`: architecture, boot flow, roadmap, debug notes

## Memory map

| Address range | Chuc nang |
| --- | --- |
| `0x0000_0000` - `0x0000_3FFF` | Boot ROM (16 KB) |
| `0x1000_0000` - `0x1000_FFFF` | Unified SRAM (64 KB) |
| `0x2000_0000` - `0x2000_0007` | UART divider / data |
| `0x2000_1000` - `0x2000_1003` | GPIO output |
| `0x2000_2000` - `0x2000_2013` | Timer counter / compare |
| `0x2000_3000` - `0x2000_3007` | SPI master |
| `0x2000_4000` - `0x2000_4007` | PS/2 keyboard |

## Trang thai hien tai

Repo nay da duoc khoi tao tu project Basys 3/PicoRV32 co san cua ban o `E:\riscvpicorv32\RISC_V_PicoRV32`, nhung da duoc sap xep lai theo huong de mo rong thanh mot mini personal computer.

Phien ban hien tai cung cap:

- core `picorv32.v` chinh thuc
- SoC memory-mapped don gian
- boot ROM monitor image co san de test synth/sim ngay
- source firmware boot ROM de phat trien tiep
- VGA test pattern de bring-up man hinh
- PS/2 va SPI o muc khoi tao/phat trien tiep
- testbench smoke test cho Vivado simulation

## Cach dung nhanh

1. Mo Vivado TCL console.
2. Chay:

```tcl
cd <duong-dan-repo>
source scripts/create_vivado_project.tcl
```

3. Set top la `top_basys3`.
4. Behavioral simulation:

```tcl
set_property top top_basys3_tb [get_filesets sim_1]
launch_simulation
```

5. Neu muon synthesize len board:
   - set top ve `top_basys3`
   - add/refresh `bootrom.mem` neu ban thay firmware
   - run synthesis -> implementation -> bitstream

## Chay smoke simulation tren Windows

Vivado cua ban da duoc tim thay o:

```text
E:\AMDDesignTools\2025.2\Vivado\bin
```

Co 2 cach:

1. GUI:
   - mo Vivado
   - `Tools -> Run Tcl Script...`
   - chon `scripts/run_vivado_smoke_sim_gui.tcl`
   - script nay se giu Vivado mo sau khi simulation xong

2. Batch tu Windows CMD:

```bat
scripts\run_vivado_smoke_sim.bat
```

Script nay se:

- tao project Vivado
- set `top_basys3_tb` cho `sim_1`
- chay behavioral simulation den khi testbench `$finish`
- ghi log vao `build\vivado_smoke_sim.log`
- dong project va thoat Vivado khi chay o che do batch

Ban smoke sim hien tai tu check 4 dau hieu:

- UART banner co chu `RV32`
- shell tra loi lenh `h` bang chuoi `CMDS:`
- shell tra loi lenh `l` bang chuoi `LED=0`
- shell tra loi lenh `b` bang chuoi `BOOT=OK`
- shell tra loi lenh `k` bang chuoi `PS2=OK`
- `LED0` thuc su toggle sau lenh UART
- `SPI SCLK` co hoat dong trong luc test `b`
- lenh `b` validate duoc header raw boot image `RVPC` qua SPI model
- `VGA HSYNC` co toggle

De regenerate `bootrom.mem` ma khong can RISC-V GCC:

```bat
scripts\gen_bootrom.bat
```

## Build va nap Basys 3 tren Windows

Sau khi smoke simulation da pass, day la duong di tiep theo de bring-up board that:

1. Tao bitstream:

```bat
scripts\run_vivado_build.bat
```

2. Nap FPGA qua JTAG:

```bat
scripts\program_basys3.bat
```

3. Sau khi nap xong, kiem tra:
   - UART ra banner monitor o `115200 8N1`
   - gui `h` de xem help
   - gui `l` de toggle `LED0`
   - man hinh VGA hien test pattern

Log mac dinh:

- `build\vivado_build.log`
- `build\program_basys3.log`

Xem them checklist chi tiet trong [Board Bring-up](docs/BOARD_BRINGUP.md).

## Goi y trien khai theo tung moc

1. Bring-up `UART + LED + SRAM` truoc, bo qua SD/VGA/PS2.
2. Them bootloader SPI-SD nhung chi doc raw sector, khong FAT32 o giai doan dau.
3. Sau khi boot duoc binary vao RAM, moi lam `VGA text mode`.
4. Sau cung moi hop nhat keyboard + monitor shell.

Neu chua co board that, hay coi behavioral simulation la "board ao" cua ban:

1. khoa duoc UART/GPIO/VGA bang testbench
2. xac nhan duoc monitor shell qua UART
3. moi moc deu can co self-check trong simulation truoc khi nghi den phan cung that

## Tai lieu

- [Architecture](docs/ARCHITECTURE.md)
- [Boot Flow](docs/BOOT_FLOW.md)
- [Boot Image Format](docs/BOOT_IMAGE_FORMAT.md)
- [Board Bring-up](docs/BOARD_BRINGUP.md)
- [Roadmap](docs/ROADMAP.md)
- [Debug Guide](docs/DEBUG_GUIDE.md)

## Third-party

- `third_party/picorv32/picorv32.v` duoc lay tu repo chinh thuc `YosysHQ/picorv32`
- License: xem `third_party/picorv32/LICENSE`
