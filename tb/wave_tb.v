// waveform testbench for the pipelined cpu
// essentially runs a program for 35 ticks and saves every signal into a vcd file, which plot_wave.py then draws as a picture
//   iverilog -s wave_tb -o build/wave_sim rtl/*.v tb/wave_tb.v
//   vvp build/wave_sim +prog=build/prog2_loop.hex
module wave_tb;
  reg  clk = 0;              // the clock, made by the testbench, starts at 0
  reg  reset;                // the restart switch
  reg  [1023:0] prog_file;   // basically holds the name of the program file to load

  cpu_pipe #(.PROG_FILE("tb/cpu_prog.hex")) dut(.clk(clk), .reset(reset));

  always #5 clk = ~clk;      // clock flips every 5 units giving a full cycle every 10

  initial begin
    $dumpfile("build/pipe.vcd");   // the file the signals get saved into
    $dumpvars(0, dut);             // save everything inside the cpu
    #1;                            // wait a tiny bit so the instruction memory finishes its own loading first
    if (!$value$plusargs("prog=%s", prog_file)) begin
      $display("give a program with +prog=file.hex");
      $finish;
    end
    $readmemh(prog_file, dut.imem.mem);
    reset = 1;
    repeat (2) @(posedge clk);
    #1 reset = 0;
    repeat (35) @(posedge clk);    // 35 ticks is enough to see a few loop trips
    $finish;
  end
endmodule
