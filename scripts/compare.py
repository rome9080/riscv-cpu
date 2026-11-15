# compares our cpu against spike for one program
#   1. the single cycle cpu has to match spike on EVERY instruction: same pc, same instruction, same register saved, same value, same stores
#   2. the pipelined cpu has to end with the same registers and memory as spike
# usage: compare.py name spike.log cpu.log pipe.log
import re
import sys

BASE = 0x80000000        # spike puts the program here, our cpu starts at 0
HALT = 0x00000063        # beq x0, x0, 0 jumps to itself, thats how every test program ends

name, spike_log, cpu_log, pipe_log = sys.argv[1:5]


def parse_spike(path):
    line_re = re.compile(r"core\s+\d+:\s+\d+\s+0x([0-9a-fA-F]+)\s+\(0x([0-9a-fA-F]+)\)(.*)")
    reg_re = re.compile(r"\bx(\d+)\s+0x([0-9a-fA-F]+)")
    mem_re = re.compile(r"\bmem\s+0x([0-9a-fA-F]+)(?:\s+0x([0-9a-fA-F]+))?")
    commits = []
    for line in open(path, errors="replace"):
        m = line_re.search(line)
        if not m:
            continue
        pc = int(m.group(1), 16)
        if pc < BASE:                        # spike runs a few boot instructions first, skip them
            continue
        instr = int(m.group(2), 16)
        rest = m.group(3)
        reg = reg_re.search(rest)
        mem = mem_re.search(rest)
        wr = (int(reg.group(1)), int(reg.group(2), 16)) if reg else None
        if wr and wr[0] == 0:
            wr = None
        store = None
        if mem and mem.group(2) is not None:     # a store has an address and data, a load only has an address
            store = (int(mem.group(1), 16), int(mem.group(2), 16))
        commits.append((pc - BASE, instr, wr, store))
        if instr == HALT:
            break
    return commits


def parse_cpu(path):
    commits = []
    for line in open(path, errors="replace"):
        p = line.split()
        if not p:
            continue
        if p[0] == "C":
            pc, instr, rd, val, st_on, st_addr, st_data = p[1:8]
            wr = (int(rd), int(val, 16)) if int(rd) != 0 else None
            store = (int(st_addr, 16), int(st_data, 16)) if int(st_on) == 1 else None
            commits.append((int(pc, 16), int(instr, 16), wr, store))
        elif p[0] == "HALT":
            return commits, True
    return commits, False


def parse_pipe(path):
    regs, mem = {}, {}
    for line in open(path, errors="replace"):
        p = line.split()
        if len(p) == 3 and p[0] == "R":
            regs[int(p[1])] = int(p[2], 16)
        elif len(p) == 3 and p[0] == "M":
            mem[int(p[1])] = int(p[2], 16)
    return regs, mem


def replay(commits):
    # works out the final registers and memory from a list of instructions that ran
    regs = {i: 0 for i in range(1, 32)}
    mem = {}
    for pc, instr, wr, store in commits:
        if wr:
            regs[wr[0]] = wr[1]
        if store:
            slot = (store[0] >> 2) & 63         # our data memory has 64 slots
            if store[1] == 0:
                mem.pop(slot, None)
            else:
                mem[slot] = store[1]
    return regs, mem


def fail(msg):
    print("FAIL %s: %s" % (name, msg))
    sys.exit(1)


spike = parse_spike(spike_log)
cpu, halted = parse_cpu(cpu_log)

if not spike or spike[-1][1] != HALT:
    fail("spike log is empty or never reached the halt instruction (check build/%s.spike.log)" % name)
if not halted:
    fail("single cycle cpu never reached the halt instruction (check build/%s.cpu.log)" % name)
if len(spike) != len(cpu):
    fail("spike ran %d instructions but the cpu ran %d" % (len(spike), len(cpu)))

for i, (s, c) in enumerate(zip(spike, cpu)):
    if s[0] != c[0] or s[1] != c[1]:
        fail("instruction %d: spike was at pc %#x running %08x, cpu was at pc %#x running %08x" % (i, s[0], s[1], c[0], c[1]))
    if s[2] != c[2]:
        fail("instruction %d (pc %#x, %08x): saved register differs, spike %s, cpu %s" % (i, s[0], s[1], s[2], c[2]))
    if s[3] != c[3]:
        fail("instruction %d (pc %#x, %08x): store differs, spike %s, cpu %s" % (i, s[0], s[1], s[3], c[3]))

exp_regs, exp_mem = replay(spike)
pipe_regs, pipe_mem = parse_pipe(pipe_log)
if not pipe_regs:
    fail("pipelined cpu printed no final state (check build/%s.pipe.log)" % name)
for r in range(1, 32):
    if pipe_regs.get(r) != exp_regs[r]:
        fail("pipelined cpu x%d = %s but spike ended with %08x" % (r, "%08x" % pipe_regs[r] if r in pipe_regs else "missing", exp_regs[r]))
if pipe_mem != exp_mem:
    fail("pipelined cpu memory %s but spike ended with %s" % (pipe_mem, exp_mem))

print("PASS %s: all %d instructions match spike, and the pipelined cpu ends with the same registers and memory" % (name, len(spike)))
