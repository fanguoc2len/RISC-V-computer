#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path


REG = {
    "zero": 0,
    "ra": 1,
    "sp": 2,
    "gp": 3,
    "tp": 4,
    "t0": 5,
    "t1": 6,
    "t2": 7,
    "s0": 8,
    "fp": 8,
    "s1": 9,
    "a0": 10,
    "a1": 11,
    "a2": 12,
    "a3": 13,
    "a4": 14,
    "a5": 15,
    "a6": 16,
    "a7": 17,
    "s2": 18,
    "s3": 19,
    "s4": 20,
    "s5": 21,
    "s6": 22,
    "s7": 23,
    "s8": 24,
    "s9": 25,
    "s10": 26,
    "s11": 27,
    "t3": 28,
    "t4": 29,
    "t5": 30,
    "t6": 31,
}


def reg(name: str) -> int:
    return REG[name]


def signed_range(value: int, bits: int) -> bool:
    lo = -(1 << (bits - 1))
    hi = (1 << (bits - 1)) - 1
    return lo <= value <= hi


def as_signed32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value if value < 0x80000000 else value - 0x100000000


class Program:
    def __init__(self) -> None:
        self.words: list[int] = []
        self.labels: dict[str, int] = {}
        self.fixups: list[tuple[str, int, tuple]] = []

    def pc(self) -> int:
        return len(self.words) * 4

    def emit(self, word: int) -> None:
        self.words.append(word & 0xFFFFFFFF)

    def label(self, name: str) -> None:
        self.labels[name] = self.pc()

    def lui(self, rd: str, imm20: int) -> None:
        self.emit(((imm20 & 0xFFFFF) << 12) | (reg(rd) << 7) | 0x37)

    def addi(self, rd: str, rs1: str, imm: int) -> None:
        assert signed_range(imm, 12)
        self.emit(((imm & 0xFFF) << 20) | (reg(rs1) << 15) | (0x0 << 12) | (reg(rd) << 7) | 0x13)

    def xori(self, rd: str, rs1: str, imm: int) -> None:
        assert signed_range(imm, 12)
        self.emit(((imm & 0xFFF) << 20) | (reg(rs1) << 15) | (0x4 << 12) | (reg(rd) << 7) | 0x13)

    def lw(self, rd: str, offset: int, rs1: str) -> None:
        assert signed_range(offset, 12)
        self.emit(((offset & 0xFFF) << 20) | (reg(rs1) << 15) | (0x2 << 12) | (reg(rd) << 7) | 0x03)

    def sw(self, rs2: str, offset: int, rs1: str) -> None:
        assert signed_range(offset, 12)
        imm = offset & 0xFFF
        self.emit(
            (((imm >> 5) & 0x7F) << 25)
            | (reg(rs2) << 20)
            | (reg(rs1) << 15)
            | (0x2 << 12)
            | ((imm & 0x1F) << 7)
            | 0x23
        )

    def sb(self, rs2: str, offset: int, rs1: str) -> None:
        assert signed_range(offset, 12)
        imm = offset & 0xFFF
        self.emit(
            (((imm >> 5) & 0x7F) << 25)
            | (reg(rs2) << 20)
            | (reg(rs1) << 15)
            | (0x0 << 12)
            | ((imm & 0x1F) << 7)
            | 0x23
        )

    def li(self, rd: str, imm: int) -> None:
        imm = as_signed32(imm)
        if signed_range(imm, 12):
            self.addi(rd, "zero", imm)
            return

        upper = (imm + 0x800) >> 12
        lower = imm - (upper << 12)
        assert signed_range(lower, 12)
        self.lui(rd, upper)
        if lower != 0:
            self.addi(rd, rd, lower)

    def beq(self, rs1: str, rs2: str, label: str) -> None:
        self.fixups.append(("beq", len(self.words), (reg(rs1), reg(rs2), label)))
        self.emit(0)

    def bne(self, rs1: str, rs2: str, label: str) -> None:
        self.fixups.append(("bne", len(self.words), (reg(rs1), reg(rs2), label)))
        self.emit(0)

    def jal(self, rd: str, label: str) -> None:
        self.fixups.append(("jal", len(self.words), (reg(rd), label)))
        self.emit(0)

    def j(self, label: str) -> None:
        self.jal("zero", label)

    def _encode_branch(self, funct3: int, rs1: int, rs2: int, imm: int) -> int:
        assert imm % 2 == 0
        assert signed_range(imm, 13)
        imm &= 0x1FFF
        return (
            (((imm >> 12) & 0x1) << 31)
            | (((imm >> 5) & 0x3F) << 25)
            | (rs2 << 20)
            | (rs1 << 15)
            | (funct3 << 12)
            | (((imm >> 1) & 0xF) << 8)
            | (((imm >> 11) & 0x1) << 7)
            | 0x63
        )

    def _encode_jal(self, rd: int, imm: int) -> int:
        assert imm % 2 == 0
        assert signed_range(imm, 21)
        imm &= 0x1FFFFF
        return (
            (((imm >> 20) & 0x1) << 31)
            | (((imm >> 1) & 0x3FF) << 21)
            | (((imm >> 11) & 0x1) << 20)
            | (((imm >> 12) & 0xFF) << 12)
            | (rd << 7)
            | 0x6F
        )

    def resolve(self) -> None:
        for kind, index, args in self.fixups:
            pc = index * 4
            if kind == "beq":
                rs1, rs2, label = args
                imm = self.labels[label] - pc
                self.words[index] = self._encode_branch(0x0, rs1, rs2, imm)
            elif kind == "bne":
                rs1, rs2, label = args
                imm = self.labels[label] - pc
                self.words[index] = self._encode_branch(0x1, rs1, rs2, imm)
            elif kind == "jal":
                rd, label = args
                imm = self.labels[label] - pc
                self.words[index] = self._encode_jal(rd, imm)
            else:
                raise ValueError(f"Unknown fixup kind: {kind}")


def putc(p: Program, uart_reg: str, tmp_reg: str, ch: int) -> None:
    p.li(tmp_reg, ch)
    p.sw(tmp_reg, 4, uart_reg)


def puts(p: Program, uart_reg: str, tmp_reg: str, text: str) -> None:
    for ch in text:
        putc(p, uart_reg, tmp_reg, ord(ch))


def spi_begin(p: Program) -> None:
    p.li("t0", 0x0B)
    p.sb("t0", 0, "s3")


def spi_end(p: Program) -> None:
    p.li("t0", 0x08)
    p.sb("t0", 0, "s3")


def spi_transfer(p: Program, tx_byte: int, wait_label: str) -> None:
    p.li("t0", tx_byte)
    p.sb("t0", 4, "s3")
    spi_begin(p)
    p.label(wait_label)
    p.lw("t1", 0, "s3")
    p.li("t0", 0x00FA0006)
    p.beq("t1", "t0", wait_label)
    p.lw("t1", 4, "s3")


def spi_expect(p: Program, tx_byte: int, expected: int, wait_label: str, ok_label: str, fail_label: str) -> None:
    spi_transfer(p, tx_byte, wait_label)
    p.li("t0", expected)
    p.beq("t1", "t0", ok_label)
    p.j(fail_label)


def build_bootrom() -> list[int]:
    uart_base = 0x20000000
    gpio_base = 0x20001000
    spi_base = 0x20003000
    ps2_base = 0x20004000
    uart_div = 868

    p = Program()

    p.li("s0", uart_base)
    p.li("s1", gpio_base)
    p.li("s2", 1)
    p.li("s3", spi_base)
    p.li("s4", ps2_base)
    p.sw("s2", 0, "s1")
    p.li("t0", uart_div)
    p.sw("t0", 0, "s0")

    boot_header = [
        0x52, 0x56, 0x50, 0x43,  # magic: 'RVPC'
        0x00, 0x00, 0x00, 0x10,  # load_addr: 0x1000_0000
        0x10, 0x00, 0x00, 0x00,  # size_bytes: 16
        0x00, 0x00, 0x00, 0x10,  # entry_addr: 0x1000_0000
        0x4C, 0x00, 0x00, 0x00,  # checksum: 4 x 0x00000013
        0x01, 0x00, 0x00, 0x00,  # version: 1
        0x00, 0x00, 0x00, 0x00,  # reserved0
        0x00, 0x00, 0x00, 0x00,  # reserved1
    ]

    puts(p, "s0", "t0", "RV32 PC\r\nh=help l=led b=boot k=ps2\r\n> ")

    p.label("main_loop")
    p.lw("a0", 4, "s0")
    p.li("t0", -1)
    p.beq("a0", "t0", "main_loop")

    p.sw("a0", 4, "s0")
    puts(p, "s0", "t0", "\r\n")

    p.li("t0", ord("h"))
    p.beq("a0", "t0", "cmd_help")
    p.li("t0", ord("?"))
    p.beq("a0", "t0", "cmd_help")
    p.li("t0", ord("l"))
    p.beq("a0", "t0", "cmd_led")
    p.li("t0", ord("b"))
    p.beq("a0", "t0", "cmd_spi")
    p.li("t0", ord("k"))
    p.beq("a0", "t0", "cmd_ps2")

    puts(p, "s0", "t0", "?\r\n> ")
    p.j("main_loop")

    p.label("cmd_help")
    puts(p, "s0", "t0", "CMDS:h l b k\r\n> ")
    p.j("main_loop")

    p.label("cmd_led")
    p.xori("s2", "s2", 1)
    p.sw("s2", 0, "s1")
    puts(p, "s0", "t0", "LED=")
    p.beq("s2", "zero", "led_zero")
    putc(p, "s0", "t0", ord("1"))
    p.j("led_done")

    p.label("led_zero")
    putc(p, "s0", "t0", ord("0"))

    p.label("led_done")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("cmd_spi")
    for index, expected in enumerate(boot_header):
        ok_label = "boot_ok" if index == len(boot_header) - 1 else f"boot_ok_{index}"
        spi_expect(p, 0xFF, expected, f"boot_wait_{index}", ok_label, "boot_fail")
        if index != len(boot_header) - 1:
            p.label(ok_label)

    p.label("boot_ok")
    spi_end(p)
    puts(p, "s0", "t0", "BOOT=OK\r\n> ")
    p.j("main_loop")

    p.label("boot_fail")
    spi_end(p)
    puts(p, "s0", "t0", "BOOT=ER\r\n> ")
    p.j("main_loop")

    p.label("cmd_ps2")
    p.lw("t1", 4, "s4")
    p.li("t0", 0x01)
    p.beq("t1", "t0", "ps2_read_data")
    puts(p, "s0", "t0", "PS2=ER\r\n> ")
    p.j("main_loop")

    p.label("ps2_read_data")
    p.lw("t1", 0, "s4")
    p.li("t0", 0x1C)
    p.beq("t1", "t0", "ps2_ok")
    puts(p, "s0", "t0", "PS2=ER\r\n> ")
    p.j("main_loop")

    p.label("ps2_ok")
    puts(p, "s0", "t0", "PS2=OK\r\n> ")
    p.j("main_loop")

    p.resolve()
    return p.words


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate bootrom.mem without an external RISC-V toolchain.")
    parser.add_argument("--stdout", action="store_true", help="Write the generated memory image to stdout.")
    parser.add_argument("--output", type=Path, help="Explicit output path for bootrom.mem.")
    args = parser.parse_args()

    repo_dir = Path(__file__).resolve().parent.parent
    output_path = args.output or (repo_dir / "bootrom.mem")
    words = build_bootrom()
    contents = "".join(f"{word:08x}\n" for word in words)

    if args.stdout:
        sys.stdout.write(contents)
        return

    output_path.write_text(contents, encoding="ascii")
    print(f"Wrote {len(words)} words to {output_path}")


if __name__ == "__main__":
    main()
