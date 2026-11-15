#!/bin/bash
# prints how many ticks each test program takes on the pipelined cpu
# run scripts/run_compare.sh first so the build/*.hex files exist, then:   bash scripts/perf.sh
cd "$(dirname "$0")/.." || exit 1
iverilog -s perf_tb -o build/perf_sim rtl/*.v tb/perf_tb.v || exit 1
for hex in build/prog*.hex; do
  name=$(basename "$hex" .hex)
  printf "%-12s " "$name"
  vvp build/perf_sim +prog="$hex" | grep cycles
done
