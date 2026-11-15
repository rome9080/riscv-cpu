#!/bin/bash
# compares our cpu against the spike reference simulator on every program in sw/
# run it from anywhere:   bash scripts/run_compare.sh
cd "$(dirname "$0")/.." || exit 1
mkdir -p build

# build the two testbenches once
iverilog -s trace_tb -o build/trace_sim rtl/*.v tb/trace_tb.v || exit 1
iverilog -s pipe_final_tb -o build/pipe_final_sim rtl/*.v tb/pipe_final_tb.v || exit 1

failed=0
for src in sw/*.s; do
  name=$(basename "$src" .s)

  # assemble and link the program so it starts at 0x80000000, which is where spike starts running
  riscv64-unknown-elf-as -march=rv32i -mabi=ilp32 "$src" -o "build/$name.o" || { echo "FAIL $name: assembler error"; failed=1; continue; }
  riscv64-unknown-elf-ld -m elf32lriscv -Ttext=0x80000000 -e _start "build/$name.o" -o "build/$name.elf" || { echo "FAIL $name: linker error"; failed=1; continue; }

  # turn it into the hex file our instruction memory loads
  riscv64-unknown-elf-objcopy -O binary "build/$name.elf" "build/$name.bin"
  python3 scripts/bin2hex.py "build/$name.bin" "build/$name.hex"

  # run it on spike with a log of every instruction, the halt loop never ends so we only keep the first 5000 lines
  timeout 20 spike --isa=rv32i --log-commits "build/$name.elf" 2>&1 | head -n 5000 > "build/$name.spike.log"

  # run it on our two cpus
  vvp build/trace_sim +prog="build/$name.hex" > "build/$name.cpu.log"
  vvp build/pipe_final_sim +prog="build/$name.hex" > "build/$name.pipe.log"

  python3 scripts/compare.py "$name" "build/$name.spike.log" "build/$name.cpu.log" "build/$name.pipe.log" || failed=1
done

if [ "$failed" -eq 0 ]; then echo "ALL PROGRAMS MATCH SPIKE"; else echo "SOME PROGRAMS FAILED"; fi
exit $failed
