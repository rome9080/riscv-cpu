# 32-bit RISC-V CPU in Verilog

A single-cycle 32-bit RISC-V CPU designed from scratch in Verilog. It is built from seven blocks. Each block was written and tested on its own with a self-checking testbench, then wired together into one CPU that runs real programs in simulation.

**Status:** single-cycle CPU and a 5-stage pipelined version (with forwarding, a load-use stall, and branch flushing) both working in simulation. A comparison against the Spike reference simulator and an FPGA demo are planned.

## What it does

Every clock tick, the CPU fetches one instruction, decodes it, runs it, and saves the result. The loop looks like this:

1. The program counter gives an address to the instruction memory, which returns a 32-bit instruction.
2. The control unit reads the opcode and sets the switches for every other block.
3. The register file reads two registers while the immediate generator pulls out the constant.
4. The ALU does the math, and the data memory is read or written if the instruction needs it.
5. The result is saved back into a register, and the program counter moves to `pc + 4` or to a branch target.

## Supported instructions

| Instruction | What it does |
|---|---|
| `add`, `sub` | register + register, register - register |
| `and`, `or` | bitwise and, bitwise or of two registers |
| `addi` | register + constant |
| `lw` | load a 32-bit word from memory into a register |
| `sw` | store a 32-bit word from a register into memory |
| `beq`, `bne` | jump if two registers are equal, jump if they are not equal |
| `jal` | always jump, and save `pc + 4` in a register so the program can come back |

This is a subset of RV32I. The remaining RV32I instructions (such as `xor`, shifts, `jalr`, and the byte and half-word loads and stores) are not implemented yet. The control unit does nothing for any instruction it doesn't support.

## Block diagram

```
                +------------------------------------------------+
                |                                                |
                v                                                |
          +-----------+   pc   +--------------+   instr          |
 reset -> |  program  |------->| instruction  |-----+            |
 clk   -> |  counter  |        |   memory     |     |            |
          +-----------+        +--------------+     |            |
                ^                                   v            |
                |                   +-----------------------+    |
                |  branch & zero    |      control unit     |    |
                +-------------------|  (opcode, funct bits) |    |
                |                   +-----------------------+    |
                |                    |reg_write |alu_src |alu_op |mem_write
                |                    v          v        v       v
                |    +----------------+   +-----+   +-----+   +-------------+
                |    |  register file |-->| mux |-->| ALU |-->| data memory |
                |    | (32 x 32 bits) |   +-----+   +-----+   +-------------+
                |    +----------------+      ^         |             |
                |             ^              |         |             |
                |             |   +-----------------+  |             |
                |             |   | immediate gen   |  |             |
                |             |   +-----------------+  |             |
                |             |                        v             v
                |             +----------------- mux (mem_to_reg) <--+
                |
                +--- pc + 4, or pc + immediate for a taken branch
```

## Pipelined version

`rtl/cpu_pipe.v` is the same CPU built as a 5-stage assembly line, reusing the same seven blocks. Five instructions are in flight at once, one per stage:

| Stage | What happens |
|---|---|
| IF (fetch) | get the instruction |
| ID (decode) | read registers, build the constant, set the control switches |
| EX (execute) | the ALU does the math, branches and jumps are decided |
| MEM | `lw` and `sw` use data memory |
| WB (write back) | the result is saved in a register |

What it adds on top of the single-cycle design:

- **Pipeline registers** between every stage (IF/ID, ID/EX, EX/MEM, MEM/WB).
- **Forwarding:** if an instruction needs a result the instruction ahead of it just made, the result is taken straight from the pipeline register instead of waiting for it to be saved. It can come from the EX/MEM or MEM/WB register, and the register file also passes a result through when it is read and written on the same tick.
- **Load-use stall:** a number loaded by `lw` isn't ready until after the MEM stage, so if the next instruction needs it, the front of the pipeline waits one tick.
- **Branch flush:** branches and jumps are decided in EX, so the two instructions fetched behind a taken `beq`, `bne`, or `jal` are cancelled.

Pipelining doesn't reduce the number of ticks a program takes (the flush and stall add a few). What it enables is a faster clock, because each stage does a fifth of the work. This has not been timed on real hardware yet.

## Blocks

| Block | File | What it does |
|---|---|---|
| ALU | `rtl/alu.v` | add, subtract, AND, OR, XOR, shifts, set-less-than, plus a zero flag |
| Register file | `rtl/regfile.v` | 32 registers of 32 bits, two read ports, one write port, register 0 is always 0 |
| Program counter | `rtl/pc.v` | holds the address of the current instruction, with reset |
| Instruction memory | `rtl/instr_mem.v` | 64-word program storage, loaded from a hex file |
| Immediate generator | `rtl/imm_gen.v` | pulls the constant out of I, S, B, and J type instructions and sign extends it |
| Data memory | `rtl/data_mem.v` | 64-word memory for `lw` and `sw` |
| Control unit | `rtl/control_unit.v` | decodes the opcode and sets the eight control switches |
| Top level | `rtl/cpu.v` | wires all of the above together, adds two muxes, the `pc + 4` adder, and the branch decision |

## Verification

Every block has a self-checking testbench in `tb/` that prints `ALL TESTS PASSED` or the number of failures. The whole-CPU testbench checks the program counter, the registers, and the data memory at several points while a real program runs.

What the block tests cover:

- **ALU:** every operation, plus the zero flag.
- **Register file:** writes only happen with write enable on, register 0 can't be changed, overwriting one register doesn't affect another.
- **Program counter:** reset, counting by 4, jumping, and a reset in the middle of a run.
- **Instruction memory:** the right instruction comes back for each address, and empty slots read as 0.
- **Immediate generator:** positive and negative constants for each instruction type, including the largest and smallest values that fit.
- **Data memory:** write then read back, write enable off blocks writes, and untouched slots read as 0.
- **Control unit:** every supported instruction sets the right switches, and unsupported ones (`xor`, `jalr`, an empty slot) do nothing.

The pipelined CPU has its own testbench, `tb/pipe_tb.v`, which runs four programs and checks the final registers and memory:

- the 5+4+3+2+1 loop and the 6 x 7 multiply (same answers as the single-cycle CPU)
- the `and`, `or`, `bne`, `jal` program
- `tb/hazard_prog.hex`, written to trigger forwarding from both pipeline registers, forwarding into a store, a load-use stall, and flushes after a taken `beq` and a `jal`

All verification is done in simulation with Icarus Verilog. It has not been run on an FPGA yet.

## Demo program

`tb/cpu_prog.hex` adds 5 + 4 + 3 + 2 + 1 using a loop, stores the answer in memory, and loads it back:

| Address | Assembly | What it does |
|---|---|---|
| 0x00 | `addi x1, x0, 5` | counter = 5 |
| 0x04 | `addi x2, x0, 0` | sum = 0 |
| 0x08 | `beq x1, x0, +16` | if the counter is 0, jump to 0x18 |
| 0x0C | `add x2, x2, x1` | sum = sum + counter |
| 0x10 | `addi x1, x1, -1` | counter = counter - 1 |
| 0x14 | `beq x0, x0, -12` | jump back to 0x08 |
| 0x18 | `sw x2, 0(x0)` | store the sum in memory |
| 0x1C | `lw x3, 0(x0)` | load it back into x3 |
| 0x20 | `beq x0, x0, 0` | halt (jumps to itself) |

The CPU finishes with `x2 = 15`, `x3 = 15`, and memory slot 0 = 15.

`tb/mult_prog.hex` is a second program that computes 6 x 7 = 42 by adding 7 six times. Run it with `vvp cpu_demo_sim +prog=tb/mult_prog.hex`. It runs on the same hardware with no changes, only a different program.

## How to run it

Needs [Icarus Verilog](https://github.com/steveicarus/iverilog) and [GTKWave](https://gtkwave.sourceforge.net/). On Ubuntu:

```
sudo apt install iverilog gtkwave
```

Run the whole-CPU test:

```
iverilog -o cpu_sim rtl/*.v tb/cpu_tb.v
vvp cpu_sim
```

Watch the CPU run, one line per instruction:

```
iverilog -o cpu_demo_sim rtl/*.v tb/cpu_demo_tb.v
vvp cpu_demo_sim
```

View the waveform:

```
gtkwave cpu.vcd
```

Run the pipelined CPU on each of the four programs (0 = loop, 1 = multiply, 2 = new instructions, 3 = hazards):

```
iverilog -s pipe_tb -o pipe_sim rtl/*.v tb/pipe_tb.v
vvp pipe_sim +test=0
vvp pipe_sim +test=3
```

Add `+trace` to print what the pipeline is doing every tick.

Test a single block, for example the ALU:

```
iverilog -o alu_sim rtl/alu.v tb/alu_tb.v
vvp alu_sim
```

Run every command from the repository root, because the testbenches load their program files using paths like `tb/cpu_prog.hex`.

## Repository layout

```
rtl/   the CPU design, one file per block plus cpu.v (single cycle) and cpu_pipe.v (pipelined) at the top
tb/    a testbench for each block, the whole CPU testbenches, and the program files
```

## Roadmap

- [x] Seven blocks designed and tested individually
- [x] Single-cycle CPU wired together and running a loop in simulation
- [x] `and`, `or`, `bne`, and `jal` added and tested (`tb/ext_tb.v`)
- [ ] Remaining RV32I instructions (`xor`, shifts, `jalr`, and the rest)
- [x] 5-stage pipeline with forwarding, load-use stall, and branch flush (`tb/pipe_tb.v`)
- [ ] Compare the CPU against the Spike reference simulator and measure performance
- [ ] Run on an FPGA board with a UART for text output

## Author

Roman Wasil, electrical engineering student at Toronto Metropolitan University.
