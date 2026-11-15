// performance testbench for the pipelined cpu
// essentially runs a program and counts how many ticks it took to get to the halt loop, and how many ticks were wasted
// wasted ticks come from two places: stalls (load-use) and flushes (a taken branch or jump throws away the wrong instructions)
//   iverilog -s perf_tb -o build/perf_sim rtl/*.v tb/perf_tb.v
//   vvp build/perf_sim +prog=build/prog4_fib.hex
module perf_tb;
  reg  clk = 0;              // the clock, made by the testbench, starts at 0
  reg  reset;                // the restart switch
  reg  [1023:0] prog_file;   // basically holds the name of the program file to load
  integer cycles  = 0;       // total ticks since the reset let go
  integer stalls  = 0;       // ticks lost to load-use stalls
  integer flushes = 0;       // number of taken branches/jumps (each one throws away instructions)

  cpu_pipe #(.PROG_FILE("tb/cpu_prog.hex")) dut(.clk(clk), .reset(reset));

  always #5 clk = ~clk;      // clock flips every 5 units giving a full cycle every 10

  initial begin
    #1;                      // wait a tiny bit so the instruction memory finishes its own loading first
    if (!$value$plusargs("prog=%s", prog_file)) begin
      $display("give a program with +prog=file.hex");
      $finish;
    end
    $readmemh(prog_file, dut.imem.mem);
    reset = 1;
    repeat (2) @(posedge clk);
    #1 reset = 0;
  end

  // count on the falling edge so everything has settled
  always @(negedge clk) begin
    if (!reset) begin
      cycles = cycles + 1;
      if (dut.stall)       stalls  = stalls + 1;
      if (dut.take_branch) flushes = flushes + 1;
      // the halt (beq x0,x0,0) reaching the decode station means the real program is done
      if (dut.if_id_instr == 32'h00000063) begin
        $display("cycles=%0d stalls=%0d flushes=%0d", cycles, stalls, flushes);
        $finish;
      end
    end
  end
endmodule
