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


def u32le_bytes(value: int) -> list[int]:
    value &= 0xFFFFFFFF
    return [(value >> shift) & 0xFF for shift in (0, 8, 16, 24)]


def sum32_le_words(payload: list[int]) -> int:
    payload_bytes = bytes(payload)
    padded = payload_bytes + bytes((-len(payload_bytes)) % 4)
    checksum = 0
    for offset in range(0, len(padded), 4):
        checksum = (checksum + int.from_bytes(padded[offset:offset + 4], "little")) & 0xFFFFFFFF
    return checksum


def words_to_le_bytes(words: list[int]) -> list[int]:
    payload: list[int] = []
    for word in words:
        payload.extend(u32le_bytes(word))
    return payload


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

    def andi(self, rd: str, rs1: str, imm: int) -> None:
        assert signed_range(imm, 12)
        self.emit(((imm & 0xFFF) << 20) | (reg(rs1) << 15) | (0x7 << 12) | (reg(rd) << 7) | 0x13)

    def slli(self, rd: str, rs1: str, shamt: int) -> None:
        assert 0 <= shamt < 32
        self.emit(((shamt & 0x1F) << 20) | (reg(rs1) << 15) | (0x1 << 12) | (reg(rd) << 7) | 0x13)

    def srli(self, rd: str, rs1: str, shamt: int) -> None:
        assert 0 <= shamt < 32
        self.emit(((shamt & 0x1F) << 20) | (reg(rs1) << 15) | (0x5 << 12) | (reg(rd) << 7) | 0x13)

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

    def add(self, rd: str, rs1: str, rs2: str) -> None:
        self.emit((0x00 << 25) | (reg(rs2) << 20) | (reg(rs1) << 15) | (0x0 << 12) | (reg(rd) << 7) | 0x33)

    def or_(self, rd: str, rs1: str, rs2: str) -> None:
        self.emit((0x00 << 25) | (reg(rs2) << 20) | (reg(rs1) << 15) | (0x6 << 12) | (reg(rd) << 7) | 0x33)

    def sltu(self, rd: str, rs1: str, rs2: str) -> None:
        self.emit((0x00 << 25) | (reg(rs2) << 20) | (reg(rs1) << 15) | (0x3 << 12) | (reg(rd) << 7) | 0x33)

    def r_type(self, rd: str, rs1: str, rs2: str, funct3: int, funct7: int, opcode: int) -> None:
        self.emit(
            ((funct7 & 0x7F) << 25)
            | (reg(rs2) << 20)
            | (reg(rs1) << 15)
            | ((funct3 & 0x7) << 12)
            | (reg(rd) << 7)
            | (opcode & 0x7F)
        )

    def pcpi_dot4(self, rd: str, rs1: str, rs2: str) -> None:
        self.r_type(rd, rs1, rs2, funct3=0x0, funct7=0x2A, opcode=0x0B)

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

    def jalr(self, rd: str, rs1: str, imm: int) -> None:
        assert signed_range(imm, 12)
        self.emit(((imm & 0xFFF) << 20) | (reg(rs1) << 15) | (0x0 << 12) | (reg(rd) << 7) | 0x67)

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
                try:
                    self.words[index] = self._encode_branch(0x0, rs1, rs2, imm)
                except AssertionError as exc:
                    raise AssertionError(f"Branch out of range: beq at word {index} to label {label} (imm={imm}).") from exc
            elif kind == "bne":
                rs1, rs2, label = args
                imm = self.labels[label] - pc
                try:
                    self.words[index] = self._encode_branch(0x1, rs1, rs2, imm)
                except AssertionError as exc:
                    raise AssertionError(f"Branch out of range: bne at word {index} to label {label} (imm={imm}).") from exc
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
    spi_end(p)


def spi_expect(p: Program, tx_byte: int, expected: int, wait_label: str, ok_label: str, fail_label: str) -> None:
    spi_transfer(p, tx_byte, wait_label)
    p.li("t0", expected)
    p.beq("t1", "t0", ok_label)
    p.j(fail_label)


def copy_reg(p: Program, rd: str, rs: str) -> None:
    p.addi(rd, rs, 0)


def put_hex_word(p: Program, src_reg: str, prefix: str) -> None:
    for shift in (28, 24, 20, 16, 12, 8, 4, 0):
        digit_label = f"{prefix}_digit_{shift}"
        done_label = f"{prefix}_digit_done_{shift}"
        p.srli("t0", src_reg, shift)
        p.andi("t0", "t0", 0xF)
        p.li("a4", 10)
        p.sltu("a5", "t0", "a4")
        p.bne("a5", "zero", digit_label)
        p.addi("t0", "t0", 55)
        p.j(done_label)
        p.label(digit_label)
        p.addi("t0", "t0", 48)
        p.label(done_label)
        p.sw("t0", 4, "s0")


def put_hex_byte(p: Program, src_reg: str, prefix: str) -> None:
    for shift in (4, 0):
        digit_label = f"{prefix}_digit_{shift}"
        done_label = f"{prefix}_digit_done_{shift}"
        p.srli("t0", src_reg, shift)
        p.andi("t0", "t0", 0xF)
        p.li("a4", 10)
        p.sltu("a5", "t0", "a4")
        p.bne("a5", "zero", digit_label)
        p.addi("t0", "t0", 55)
        p.j(done_label)
        p.label(digit_label)
        p.addi("t0", "t0", 48)
        p.label(done_label)
        p.sw("t0", 4, "s0")


def read_u32_le(p: Program, dst_reg: str, prefix: str) -> None:
    spi_transfer(p, 0xFF, f"{prefix}_wait_b0")
    copy_reg(p, "t3", "t1")
    spi_transfer(p, 0xFF, f"{prefix}_wait_b1")
    copy_reg(p, "t4", "t1")
    spi_transfer(p, 0xFF, f"{prefix}_wait_b2")
    copy_reg(p, "t5", "t1")
    spi_transfer(p, 0xFF, f"{prefix}_wait_b3")
    copy_reg(p, "t6", "t1")

    p.slli("t4", "t4", 8)
    p.slli("t5", "t5", 16)
    p.slli("t6", "t6", 24)
    copy_reg(p, dst_reg, "t3")
    p.or_(dst_reg, dst_reg, "t4")
    p.or_(dst_reg, dst_reg, "t5")
    p.or_(dst_reg, dst_reg, "t6")


def build_sample_app(
    sram_base: int,
    gpio_base: int,
    uart_base: int,
    boot_info_magic: int,
    sample_entry_addr: int,
) -> list[int]:
    p = Program()

    p.li("t0", sram_base)
    p.lw("t1", 0, "t0")
    p.li("t2", boot_info_magic)
    p.bne("t1", "t2", "app_fail")

    p.lw("t1", 12, "t0")
    p.li("t2", sample_entry_addr)
    p.bne("t1", "t2", "app_fail")

    p.li("t0", gpio_base)
    p.li("t1", 0xA)
    p.sw("t1", 0, "t0")

    p.li("t0", uart_base)
    p.li("t1", ord("I"))
    p.sw("t1", 4, "t0")
    p.li("t1", ord("G"))
    p.sw("t1", 4, "t0")
    p.j("app_halt")

    p.label("app_fail")
    p.li("t0", uart_base)
    p.li("t1", ord("E"))
    p.sw("t1", 4, "t0")

    p.label("app_halt")
    p.j("app_halt")

    p.resolve()
    return words_to_le_bytes(p.words)


def build_bootrom() -> list[int]:
    uart_base = 0x20000000
    gpio_base = 0x20001000
    timer_base = 0x20002000
    spi_base = 0x20003000
    ps2_base = 0x20004000
    npu_base = 0x20005000
    sram_base = 0x10000000
    sram_bytes = 0x00010000
    sample_load_addr = sram_base + 0x20
    sample_entry_addr = sample_load_addr
    boot_info_magic = 0x49425652
    boot_status_ok = 0x00000001
    boot_status_bad_magic = 0x000000E1
    boot_status_bad_range = 0x000000E2
    boot_status_bad_size = 0x000000E3
    boot_status_bad_entry = 0x000000E4
    boot_status_bad_checksum = 0x000000E5
    uart_div = 868
    ramtest_min_base = sram_base + 0x200
    ramtest_limit = sram_base + sram_bytes - 0x200
    npu_demo_vec_a = 0xFC03FE01
    npu_demo_vec_b = 0xFC05FA07
    npu_demo_expected = 0x00000032
    npu_vec16_pairs = [
        (0xFC03FE01, 0xFC05FA07),
        (0xF8F90605, 0xFF0102FD),
        (0x04FD02FF, 0xF906FB04),
        (0xF40BF609, 0x05FC03FE),
    ]
    npu_vec16_expected = 0xFFFFFF5C
    npu_mat4_expected = [0x00000032, 0xFFFFFFFC, 0xFFFFFFCE, 0x000000E2]

    p = Program()

    p.li("s0", uart_base)
    p.li("s1", gpio_base)
    p.li("s2", 1)
    p.li("s3", spi_base)
    p.li("s4", ps2_base)
    p.li("s5", 0)
    p.li("s6", sram_base)
    p.li("s7", 0)
    p.li("s8", sram_base)
    p.li("s9", 0)
    p.li("s10", 0)
    p.li("s11", 0)
    p.sw("s2", 0, "s1")
    p.li("t0", uart_div)
    p.sw("t0", 0, "s0")

    boot_payload = build_sample_app(sram_base, gpio_base, uart_base, boot_info_magic, sample_entry_addr)
    boot_header = [
        0x52, 0x56, 0x50, 0x43,  # magic: 'RVPC'
        *u32le_bytes(sample_load_addr),
        *u32le_bytes(len(boot_payload)),
        *u32le_bytes(sample_entry_addr),
        *u32le_bytes(sum32_le_words(boot_payload)),
        *u32le_bytes(1),
        *u32le_bytes(0),
        *u32le_bytes(0),
    ]

    puts(p, "s0", "t0", "RV32 PC\r\nh=help c=clear l=led b=boot k=ps2 i=info m=mem t=time r=ram n=npu p=pcpi v=vec16 x=mat g=go\r\n> ")
    p.j("boot_try")

    p.label("main_loop")
    p.lw("a0", 4, "s0")
    p.li("t0", -1)
    p.bne("a0", "t0", "dispatch_input")
    p.lw("t1", 4, "s4")
    p.li("t0", 0x01)
    p.beq("t1", "t0", "poll_ps2")
    p.j("main_loop")

    p.label("poll_ps2")
    p.lw("a1", 0, "s4")
    p.li("t0", 0xF0)
    p.beq("a1", "t0", "ps2_mark_break")
    p.li("t0", 0xE0)
    p.beq("a1", "t0", "ps2_mark_extend")
    p.andi("t0", "gp", 0x01)
    p.bne("t0", "zero", "ps2_clear_flags")
    p.andi("t0", "gp", 0x02)
    p.bne("t0", "zero", "ps2_clear_flags")
    p.li("t0", 0x1C)
    p.beq("a1", "t0", "ps2_key_a")
    p.li("t0", 0x21)
    p.beq("a1", "t0", "ps2_key_c")
    p.li("t0", 0x22)
    p.beq("a1", "t0", "ps2_key_x")
    p.li("t0", 0x32)
    p.beq("a1", "t0", "ps2_key_b")
    p.li("t0", 0x34)
    p.beq("a1", "t0", "ps2_key_g")
    p.li("t0", 0x33)
    p.beq("a1", "t0", "ps2_key_h")
    p.li("t0", 0x43)
    p.beq("a1", "t0", "ps2_key_i")
    p.li("t0", 0x42)
    p.beq("a1", "t0", "ps2_key_k")
    p.li("t0", 0x4B)
    p.beq("a1", "t0", "ps2_key_l")
    p.li("t0", 0x3A)
    p.beq("a1", "t0", "ps2_key_m")
    p.li("t0", 0x31)
    p.beq("a1", "t0", "ps2_key_n")
    p.li("t0", 0x4D)
    p.beq("a1", "t0", "ps2_key_p")
    p.li("t0", 0x2D)
    p.beq("a1", "t0", "ps2_key_r")
    p.li("t0", 0x2C)
    p.beq("a1", "t0", "ps2_key_t")
    p.li("t0", 0x2A)
    p.beq("a1", "t0", "ps2_key_v")
    p.j("main_loop")

    p.label("ps2_mark_break")
    p.li("gp", 0x01)
    p.j("main_loop")

    p.label("ps2_mark_extend")
    p.li("gp", 0x02)
    p.j("main_loop")

    p.label("ps2_clear_flags")
    p.li("gp", 0x00)
    p.j("main_loop")

    p.label("ps2_key_a")
    p.li("a0", ord("a"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_c")
    p.li("a0", ord("c"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_x")
    p.li("a0", ord("x"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_b")
    p.li("a0", ord("b"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_g")
    p.li("a0", ord("g"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_h")
    p.li("a0", ord("h"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_i")
    p.li("a0", ord("i"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_k")
    p.li("a0", ord("k"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_l")
    p.li("a0", ord("l"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_m")
    p.li("a0", ord("m"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_n")
    p.li("a0", ord("n"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_p")
    p.li("a0", ord("p"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_r")
    p.li("a0", ord("r"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_t")
    p.li("a0", ord("t"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_key_v")
    p.li("a0", ord("v"))
    p.j("ps2_store_and_dispatch")

    p.label("ps2_store_and_dispatch")
    p.li("gp", 0x00)
    p.li("t2", sram_base)
    p.sw("a1", 24, "t2")
    p.sw("a0", 28, "t2")

    p.label("dispatch_input")

    p.sw("a0", 4, "s0")
    puts(p, "s0", "t0", "\r\n")

    p.li("t0", ord("h"))
    p.beq("a0", "t0", "cmd_help_stub")
    p.li("t0", ord("?"))
    p.beq("a0", "t0", "cmd_help_stub")
    p.li("t0", ord("l"))
    p.beq("a0", "t0", "cmd_led_stub")
    p.li("t0", ord("c"))
    p.beq("a0", "t0", "cmd_clear_stub")
    p.li("t0", ord("b"))
    p.beq("a0", "t0", "cmd_spi_stub")
    p.li("t0", ord("k"))
    p.beq("a0", "t0", "cmd_ps2_stub")
    p.li("t0", ord("i"))
    p.beq("a0", "t0", "cmd_info_stub")
    p.li("t0", ord("m"))
    p.beq("a0", "t0", "cmd_mem_stub")
    p.li("t0", ord("t"))
    p.beq("a0", "t0", "cmd_time_stub")
    p.li("t0", ord("r"))
    p.beq("a0", "t0", "cmd_ram_stub")
    p.li("t0", ord("n"))
    p.beq("a0", "t0", "cmd_npu_stub")
    p.li("t0", ord("p"))
    p.beq("a0", "t0", "cmd_pcpi_stub")
    p.li("t0", ord("v"))
    p.beq("a0", "t0", "cmd_vec16_stub")
    p.li("t0", ord("x"))
    p.beq("a0", "t0", "cmd_matvec_stub")
    p.li("t0", ord("g"))
    p.beq("a0", "t0", "cmd_go_stub")

    puts(p, "s0", "t0", "?\r\n> ")
    p.j("main_loop")

    p.label("cmd_help_stub")
    p.j("cmd_help")

    p.label("cmd_led_stub")
    p.j("cmd_led")

    p.label("cmd_time_stub")
    p.j("cmd_time")

    p.label("cmd_clear_stub")
    p.j("cmd_clear")

    p.label("cmd_spi_stub")
    p.j("cmd_spi")

    p.label("cmd_ps2_stub")
    p.j("cmd_ps2")

    p.label("cmd_info_stub")
    p.j("cmd_info")

    p.label("cmd_mem_stub")
    p.j("cmd_mem")

    p.label("cmd_ram_stub")
    p.j("cmd_ram")

    p.label("cmd_npu_stub")
    p.j("cmd_npu")

    p.label("cmd_pcpi_stub")
    p.j("cmd_pcpi")

    p.label("cmd_vec16_stub")
    p.j("cmd_vec16")

    p.label("cmd_matvec_stub")
    p.j("cmd_matvec")

    p.label("cmd_go_stub")
    p.j("cmd_go")

    p.label("cmd_help")
    puts(p, "s0", "t0", "CMDS:h c l b k i m t r n p v x g\r\n> ")
    p.j("main_loop")

    p.label("cmd_clear")
    putc(p, "s0", "t0", 0x0C)
    puts(p, "s0", "t0", "> ")
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
    p.j("boot_try")

    p.label("boot_try")
    p.li("s5", 0)
    p.li("t0", sram_base)
    p.sw("zero", 0, "t0")
    p.sw("zero", 4, "t0")
    p.sw("zero", 8, "t0")
    p.sw("zero", 12, "t0")
    p.sw("zero", 16, "t0")
    p.sw("zero", 20, "t0")
    p.sw("zero", 24, "t0")
    p.sw("zero", 28, "t0")
    for index, expected in enumerate(boot_header[:4]):
        ok_label = f"boot_ok_{index}"
        spi_expect(p, 0xFF, expected, f"boot_wait_{index}", ok_label, "boot_bad_magic")
        if index != len(boot_header[:4]) - 1:
            p.label(ok_label)

    p.label("boot_ok_3")
    read_u32_le(p, "s6", "boot_load_addr")
    read_u32_le(p, "s7", "boot_size")
    read_u32_le(p, "s8", "boot_entry")
    read_u32_le(p, "s9", "boot_checksum")

    for index, expected in enumerate(boot_header[20:]):
        ok_label = "boot_tail_ok" if index == len(boot_header[20:]) - 1 else f"boot_tail_ok_{index}"
        spi_expect(p, 0xFF, expected, f"boot_tail_wait_{index}", ok_label, "boot_bad_magic")
        if index != len(boot_header[20:]) - 1:
            p.label(ok_label)

    p.label("boot_tail_ok")
    p.li("t0", sram_base)
    p.sltu("t2", "s6", "t0")
    p.bne("t2", "zero", "boot_bad_range")

    p.beq("s7", "zero", "boot_bad_size")
    p.li("t0", sram_bytes)
    p.sltu("t2", "t0", "s7")
    p.bne("t2", "zero", "boot_bad_size")

    p.add("s11", "s6", "s7")
    p.sltu("t2", "s11", "s6")
    p.bne("t2", "zero", "boot_bad_range")

    p.li("t0", sram_base + sram_bytes)
    p.sltu("t2", "t0", "s11")
    p.bne("t2", "zero", "boot_bad_range")

    p.sltu("t2", "s8", "s6")
    p.bne("t2", "zero", "boot_bad_entry")
    p.sltu("t2", "s8", "s11")
    p.beq("t2", "zero", "boot_bad_entry")

    copy_reg(p, "t2", "s6")
    copy_reg(p, "t3", "s7")
    p.li("t4", 0)
    p.li("t5", 0)
    p.li("s10", 0)
    p.label("payload_loop")
    spi_transfer(p, 0xFF, "payload_wait")
    p.sb("t1", 0, "t2")
    p.li("t0", 1)
    p.beq("t4", "t0", "payload_lane1")
    p.li("t0", 2)
    p.beq("t4", "t0", "payload_lane2")
    p.li("t0", 3)
    p.beq("t4", "t0", "payload_lane3")
    copy_reg(p, "t5", "t1")
    p.li("t4", 1)
    p.j("payload_byte_done")

    p.label("payload_lane1")
    p.slli("t6", "t1", 8)
    p.or_("t5", "t5", "t6")
    p.li("t4", 2)
    p.j("payload_byte_done")

    p.label("payload_lane2")
    p.slli("t6", "t1", 16)
    p.or_("t5", "t5", "t6")
    p.li("t4", 3)
    p.j("payload_byte_done")

    p.label("payload_lane3")
    p.slli("t6", "t1", 24)
    p.or_("t5", "t5", "t6")
    p.add("s10", "s10", "t5")
    p.li("t5", 0)
    p.li("t4", 0)

    p.label("payload_byte_done")
    p.addi("t2", "t2", 1)
    p.addi("t3", "t3", -1)
    p.bne("t3", "zero", "payload_loop")

    p.beq("t4", "zero", "payload_checksum_done")
    p.add("s10", "s10", "t5")

    p.label("payload_checksum_done")
    p.bne("s10", "s9", "boot_bad_checksum")
    p.li("t0", sram_base)
    p.li("t1", boot_info_magic)
    p.sw("t1", 0, "t0")
    p.sw("s6", 4, "t0")
    p.sw("s7", 8, "t0")
    p.sw("s8", 12, "t0")
    p.sw("s9", 16, "t0")
    p.li("t1", boot_status_ok)
    p.sw("t1", 20, "t0")
    p.sw("zero", 24, "t0")
    p.sw("zero", 28, "t0")
    p.li("s5", 1)
    puts(p, "s0", "t0", "BOOT=OK\r\n> ")
    p.j("main_loop")

    p.label("boot_bad_magic")
    p.li("a4", boot_status_bad_magic)
    p.j("boot_fail")

    p.label("boot_bad_range")
    p.li("a4", boot_status_bad_range)
    p.j("boot_fail")

    p.label("boot_bad_size")
    p.li("a4", boot_status_bad_size)
    p.j("boot_fail")

    p.label("boot_bad_entry")
    p.li("a4", boot_status_bad_entry)
    p.j("boot_fail")

    p.label("boot_bad_checksum")
    p.li("a4", boot_status_bad_checksum)
    p.j("boot_fail")

    p.label("boot_fail")
    p.li("s5", 0)
    p.li("t0", sram_base)
    p.sw("a4", 20, "t0")
    puts(p, "s0", "t0", "BOOT=ER\r\n> ")
    p.j("main_loop")

    p.label("cmd_ps2")
    p.li("t3", sram_base)
    p.lw("t1", 24, "t3")
    p.beq("t1", "zero", "ps2_no_data")
    puts(p, "s0", "t0", "PS2=OK RAW=")
    put_hex_byte(p, "t1", "ps2_raw")
    puts(p, "s0", "t0", " ASCII=")
    p.lw("t2", 28, "t3")
    p.beq("t2", "zero", "ps2_ascii_unknown")
    p.sw("t2", 4, "s0")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("ps2_ascii_unknown")
    putc(p, "s0", "t0", ord("?"))
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("ps2_no_data")
    puts(p, "s0", "t0", "PS2=ER\r\n> ")
    p.j("main_loop")

    p.label("cmd_info")
    puts(p, "s0", "t0", "BOOTLD=")
    p.beq("s5", "zero", "info_boot_zero")
    putc(p, "s0", "t0", ord("1"))
    p.j("info_boot_done")

    p.label("info_boot_zero")
    putc(p, "s0", "t0", ord("0"))

    p.label("info_boot_done")
    puts(p, "s0", "t0", " ENTRY=")
    put_hex_word(p, "s8", "info_entry")
    puts(p, "s0", "t0", " STATUS=")
    p.li("t3", sram_base)
    p.lw("t1", 20, "t3")
    put_hex_word(p, "t1", "info_status")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("cmd_mem")
    puts(p, "s0", "t0", "BI0=")
    p.li("t3", sram_base)
    p.lw("t1", 0, "t3")
    put_hex_word(p, "t1", "mem_bi0")
    puts(p, "s0", "t0", " APP0=")
    p.lw("t2", 4, "t3")
    p.lw("t1", 0, "t2")
    put_hex_word(p, "t1", "mem_app0")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("cmd_time")
    puts(p, "s0", "t0", "TIME=")
    p.li("t3", timer_base)
    p.lw("t1", 0, "t3")
    put_hex_word(p, "t1", "time_lo")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("cmd_ram")
    p.li("t3", ramtest_min_base)
    p.beq("s5", "zero", "ram_base_ready")
    p.add("t4", "s6", "s7")
    p.addi("t4", "t4", 31)
    p.andi("t4", "t4", -32)
    p.sltu("t5", "t3", "t4")
    p.beq("t5", "zero", "ram_base_ready")
    copy_reg(p, "t3", "t4")

    p.label("ram_base_ready")
    p.addi("t4", "t3", 16)
    p.li("t5", ramtest_limit)
    p.sltu("t6", "t5", "t4")
    p.bne("t6", "zero", "ram_fail")

    p.li("t0", 0x13579BDF)
    p.sw("t0", 0, "t3")
    p.li("t0", 0x2468ACE0)
    p.sw("t0", 4, "t3")
    p.li("t0", 0x0F0F55AA)
    p.sw("t0", 8, "t3")
    p.li("t0", 0xA5A5F00F)
    p.sw("t0", 12, "t3")

    p.lw("t1", 0, "t3")
    p.li("t0", 0x13579BDF)
    p.bne("t1", "t0", "ram_fail")
    p.lw("t1", 4, "t3")
    p.li("t0", 0x2468ACE0)
    p.bne("t1", "t0", "ram_fail")
    p.lw("t1", 8, "t3")
    p.li("t0", 0x0F0F55AA)
    p.bne("t1", "t0", "ram_fail")
    p.lw("t1", 12, "t3")
    p.li("t0", 0xA5A5F00F)
    p.bne("t1", "t0", "ram_fail")

    puts(p, "s0", "t0", "RAM=OK\r\n> ")
    p.j("main_loop")

    p.label("ram_fail")
    puts(p, "s0", "t0", "RAM=ER\r\n> ")
    p.j("main_loop")

    p.label("cmd_npu")
    p.li("t3", npu_base)
    p.li("t2", 0)
    p.li("t1", npu_demo_vec_a)
    p.sw("t1", 4, "t3")
    p.li("t1", npu_demo_vec_b)
    p.sw("t1", 8, "t3")
    p.li("t1", 1)
    p.sw("t1", 0, "t3")
    p.lw("t4", 0, "t3")
    p.andi("t4", "t4", 0x2)
    p.li("t1", 0x2)
    p.bne("t4", "t1", "npu_fail")
    p.lw("t2", 12, "t3")
    p.li("t1", npu_demo_expected)
    p.bne("t2", "t1", "npu_fail")
    puts(p, "s0", "t0", "NPU=OK RES=")
    put_hex_word(p, "t2", "npu_res_ok")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("npu_fail")
    puts(p, "s0", "t0", "NPU=ER RES=")
    put_hex_word(p, "t2", "npu_res_fail")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("cmd_pcpi")
    p.li("t1", npu_demo_vec_a)
    p.li("t2", npu_demo_vec_b)
    p.pcpi_dot4("t3", "t1", "t2")
    p.li("t0", npu_demo_expected)
    p.bne("t3", "t0", "pcpi_fail")
    puts(p, "s0", "t0", "PCPI=OK RES=")
    put_hex_word(p, "t3", "pcpi_res_ok")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("pcpi_fail")
    puts(p, "s0", "t0", "PCPI=ER RES=")
    put_hex_word(p, "t3", "pcpi_res_fail")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("cmd_vec16")
    p.li("t4", npu_base)
    p.li("t5", 0x6)
    p.sw("t5", 0, "t4")
    p.li("t6", 0)

    for index, (vec_a_word, vec_b_word) in enumerate(npu_vec16_pairs):
        p.li("t1", vec_a_word)
        p.sw("t1", 4, "t4")
        p.li("t2", vec_b_word)
        p.sw("t2", 8, "t4")
        p.pcpi_dot4("t3", "t1", "t2")
        p.add("t6", "t6", "t3")
        p.li("t5", 0x9 if index > 0 else 0x1)
        p.sw("t5", 0, "t4")

    p.lw("t2", 12, "t4")
    p.lw("t5", 0, "t4")
    p.andi("t5", "t5", 0x2)
    p.li("t1", 0x2)
    p.bne("t5", "t1", "vec16_fail")
    p.li("t1", npu_vec16_expected)
    p.bne("t2", "t1", "vec16_fail")
    p.bne("t6", "t1", "vec16_fail")
    puts(p, "s0", "t0", "V16=OK MMIO=")
    put_hex_word(p, "t2", "vec16_mmio_ok")
    puts(p, "s0", "t0", " PCPI=")
    put_hex_word(p, "t6", "vec16_pcpi_ok")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("vec16_fail")
    puts(p, "s0", "t0", "V16=ER MMIO=")
    put_hex_word(p, "t2", "vec16_mmio_fail")
    puts(p, "s0", "t0", " PCPI=")
    put_hex_word(p, "t6", "vec16_pcpi_fail")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("cmd_matvec")
    p.li("t4", npu_base)
    p.li("t1", npu_demo_vec_b)
    p.sw("t1", 4, "t4")
    p.li("t1", npu_vec16_pairs[0][0])
    p.sw("t1", 8, "t4")
    p.li("t1", npu_vec16_pairs[1][0])
    p.sw("t1", 16, "t4")
    p.li("t1", npu_vec16_pairs[2][0])
    p.sw("t1", 20, "t4")
    p.li("t1", npu_vec16_pairs[3][0])
    p.sw("t1", 24, "t4")
    p.li("t1", 0x10)
    p.sw("t1", 0, "t4")
    p.lw("t2", 12, "t4")
    p.lw("t3", 28, "t4")
    p.lw("t5", 32, "t4")
    p.lw("t6", 36, "t4")
    p.lw("a1", 0, "t4")
    p.andi("a1", "a1", 0x2)
    p.li("a0", 0x2)
    p.bne("a1", "a0", "matvec_fail")
    p.li("a0", npu_mat4_expected[0])
    p.bne("t2", "a0", "matvec_fail")
    p.li("a0", npu_mat4_expected[1])
    p.bne("t3", "a0", "matvec_fail")
    p.li("a0", npu_mat4_expected[2])
    p.bne("t5", "a0", "matvec_fail")
    p.li("a0", npu_mat4_expected[3])
    p.bne("t6", "a0", "matvec_fail")
    puts(p, "s0", "t0", "MAT=OK R0=")
    put_hex_word(p, "t2", "matvec_r0_ok")
    puts(p, "s0", "t0", " R1=")
    put_hex_word(p, "t3", "matvec_r1_ok")
    puts(p, "s0", "t0", " R2=")
    put_hex_word(p, "t5", "matvec_r2_ok")
    puts(p, "s0", "t0", " R3=")
    put_hex_word(p, "t6", "matvec_r3_ok")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("matvec_fail")
    puts(p, "s0", "t0", "MAT=ER R0=")
    put_hex_word(p, "t2", "matvec_r0_fail")
    puts(p, "s0", "t0", " R1=")
    put_hex_word(p, "t3", "matvec_r1_fail")
    puts(p, "s0", "t0", " R2=")
    put_hex_word(p, "t5", "matvec_r2_fail")
    puts(p, "s0", "t0", " R3=")
    put_hex_word(p, "t6", "matvec_r3_fail")
    puts(p, "s0", "t0", "\r\n> ")
    p.j("main_loop")

    p.label("cmd_go")
    p.beq("s5", "zero", "go_fail")
    p.jalr("zero", "s8", 0)

    p.label("go_fail")
    puts(p, "s0", "t0", "GO=ER\r\n> ")
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
