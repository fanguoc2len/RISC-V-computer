# Timer Interrupt Path

The Basys 3 design uses PicoRV32's optional custom interrupt mechanism. This
is intentionally small and is not the standard RISC-V privileged
architecture, CLINT, or PLIC.

## Wiring

- external timer interrupt: PicoRV32 `irq[3]`
- reset vector: `0x0000_0000`
- interrupt vector: `0x0000_0010`
- timer EOI input: PicoRV32 `eoi[3]`
- IRQs `0..2` stay masked because PicoRV32 reserves them for its internal
  timer, illegal instruction/EBREAK, and bus-error sources
- `LATCHED_IRQ[3]=0` makes the external timer source level-sensitive, avoiding
  a second pending latch while the handler is clearing the peripheral

The CPU starts with all IRQs masked. Boot ROM programs the timer compare
register as a full 64-bit `counter + delay` value (including low-word carry)
and then executes `maskirq` with only IRQ3 enabled.

## Handler Contract

The generated handler:

1. saves `t0` and `t1` into PicoRV32 q-registers `q2` and `q3`
2. clears both compare words so the level source drops
3. clears the timer pending bit with W1C
4. restores `t1` and `t0`
5. executes `retirq`

PicoRV32 supplies the interrupted PC in `q0` and the pending IRQ mask in `q1`.
The handler does not enable nesting.

## Timer Registers

| Offset | Register | Access |
| --- | --- | --- |
| `0x00` | counter low | read |
| `0x04` | counter high | read |
| `0x08` | compare low | read/write, byte strobes |
| `0x0C` | compare high | read/write, byte strobes |
| `0x10` | bit 0 pending W1C, bit 1 enable | read/write |
| `0x14` | CPU acknowledge count | read |

The acknowledge counter increments on the rising edge of `eoi[3]`, not on
every cycle that EOI remains asserted. The monitor command `t` prints both
the free-running counter and `IRQS=`, which should become `00000001` after
the one-shot boot self-test. The regression intentionally boots twice
(automatic boot plus command `b`), so its final acknowledge count is two.

## Verification

`timer_mmio_tb` verifies counter, byte strobes, compare, pending, W1C and
edge-counted EOI behavior. AXI, native-fallback and board-top regressions
require one CPU acknowledgement per successful boot and then continue through
the monitor and SRAM app, proving that the handler returned to normal
execution.
