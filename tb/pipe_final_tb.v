// final state testbench for the pipelined cpu
// essentially runs a program for plenty of ticks, then prints every register and every non zero memory slot
// the compare script checks these against what spike ended up with
//   iverilog -s pipe_final_tb -o pipe_final_sim rtl/*.v tb/pipe_final_tb.v
//   vvp pipe_final_sim +prog=build/prog1_alu.hex
module pipe_final_tb;
  reg  clk = 0;              // the clock, made by the testbench, starts at 0
  reg  reset;                // the restart switch
  reg  [1023:0] prog_file;   // basically holds the name of the program file to load
  integer i;

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
    repeat (2000) @(posedge clk);   // plenty of ticks for any of the test programs to finish and sit in the halt loop
    #1;
    for (i = 1; i < 32; i = i + 1) $display("R %0d %08h", i, dut.rf.regs[i]);
    for (i = 0; i < 64; i = i + 1) if (dut.dmem.mem[i] != 32'd0) $display("M %0d %08h", i, dut.dmem.mem[i]);
    $finish;
  end
endmodule
