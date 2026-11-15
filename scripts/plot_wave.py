#!/usr/bin/env python3
# draws the pipeline waveform from build/pipe.vcd as a picture (docs/waveform.png)
# basically reads the signals we care about out of the vcd file and plots them one row each
#   python3 scripts/plot_wave.py                      (uses build/pipe.vcd, writes docs/waveform.png)
import sys, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

vcd_path = sys.argv[1] if len(sys.argv) > 1 else "build/pipe.vcd"
out_path = sys.argv[2] if len(sys.argv) > 2 else "docs/waveform.png"

# the signals to draw, top to bottom (all of them live directly inside the cpu)
SHOW = ["clk", "pc", "if_id_instr", "stall", "pred_redirect", "mispredict"]
LABEL = {"clk": "clock", "pc": "pc (low 12 bits)", "if_id_instr": "instruction in decode",
         "stall": "stall (load-use)", "pred_redirect": "early redirect (guess: taken)",
         "mispredict": "wrong guess (fixed in EX)"}
CYCLE = 10          # the testbench clock is 10 time units per tick
START = 2 * CYCLE   # skip the 2 reset ticks

# ---- read the vcd ----
ids = {}            # vcd short code -> (name, width), only for signals directly inside dut
scope = []
changes = {}        # name -> list of (time, value as int or None for x/z)
with open(vcd_path) as f:
    t = 0
    in_defs = True
    for line in f:
        line = line.strip()
        if not line:
            continue
        if in_defs:
            if line.startswith("$scope"):
                scope.append(line.split()[2])
            elif line.startswith("$upscope"):
                scope.pop()
            elif line.startswith("$var"):
                p = line.split()
                width, code, name = int(p[2]), p[3], p[4]
                if scope and scope[-1] == "dut" and name in SHOW and name not in changes:
                    ids[code] = (name, width)
                    changes[name] = []
            elif line.startswith("$enddefinitions"):
                in_defs = False
            continue
        if line[0] == "#":
            t = int(line[1:])
        elif line[0] in "01xXzZ" and len(line) > 1 and line[1:] in ids:
            name, _ = ids[line[1:]]
            changes[name].append((t, None if line[0] in "xXzZ" else int(line[0])))
        elif line[0] == "b":
            val, code = line[1:].split()
            if code in ids:
                name, _ = ids[code]
                changes[name].append((t, None if set(val) & set("xXzZ") else int(val, 2)))

missing = [s for s in SHOW if s not in changes]
if missing:
    sys.exit("signals not found in the vcd: " + ", ".join(missing))

end = START + 30 * CYCLE   # show 30 ticks so the hex labels have room

def segments(name):
    # turn the change list into (start, stop, value) pieces
    c = changes[name]
    segs = []
    for i, (tt, v) in enumerate(c):
        stop = c[i + 1][0] if i + 1 < len(c) else end
        segs.append((tt, stop, v))
    return segs

fig, axes = plt.subplots(len(SHOW), 1, figsize=(16, 5.2), sharex=True)
for ax, name in zip(axes, SHOW):
    ax.set_yticks([])
    ax.set_ylabel(LABEL[name], rotation=0, ha="right", va="center", fontsize=8)
    for sp in ("top", "right", "left"):
        ax.spines[sp].set_visible(False)
    segs = segments(name)
    width = [w for (_, w) in ids.values()][list(n for n, _ in ids.values()).index(name)]
    for a, b, v in segs:
        a, b = max(a, START), min(b, end)
        if b <= a:
            continue
        xa, xb = (a - START) / CYCLE, (b - START) / CYCLE
        if width == 1:
            ax.step([xa, xb], [v or 0, v or 0], where="post", color="#1f6feb", lw=1.6)
            if v:
                ax.fill_between([xa, xb], 0, 1, color="#1f6feb", alpha=0.15 if name != "mispredict" else 0.35)
            ax.set_ylim(-0.2, 1.3)
        else:
            ax.add_patch(plt.Rectangle((xa, 0.1), xb - xa, 0.8, fill=False, ec="#1f6feb", lw=1.2))
            if xb - xa >= 0.9:
                txt = "x" if v is None else ("%03x" % (v & 0xfff) if name == "pc" else "%08x" % v)   # pc shows only its low 3 hex digits so the labels fit
                ax.text((xa + xb) / 2, 0.5, txt, ha="center", va="center", fontsize=6 if name == "pc" else 5)
            ax.set_ylim(0, 1)
axes[-1].set_xlabel("clock ticks since reset")
axes[-1].set_xlim(0, (end - START) / CYCLE)
fig.suptitle("5-stage pipelined RISC-V CPU running a loop (prog2_loop)", fontsize=11)
fig.tight_layout()
os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
fig.savefig(out_path, dpi=150)
print("wrote", out_path)
