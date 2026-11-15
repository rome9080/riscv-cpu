// trace testbench for the single cycle cpu
// essentially runs a program and prints one line for every instruction: what it was, what register it saved, and if it stored anything
// the compare script reads these lines and checks them against spike
//   iverilog -s trace_tb -o trace_sim rtl/*.v tb/trace_tb.v
//   vvp trace_sim +prog=build/prog1_alu.hex
module trace_tb;
  reg  clk = 0;              // the clock, made by the testbench, starts at 0
  reg  reset;                // the restart switch
  reg  [1023:0] prog_file;   // basically holds the name of the program file to load

  cpu #(.PROG_FILE("tb/cpu_prog.hex")) dut(.clk(clk), .reset(reset));

  always #5 clk = ~clk;      // clock flips every 5 units giving a full cycle every 10

  // 0 if the instruction doesnt save a register (or saves to x0 which never changes), otherwise which register it saves
  wire [4:0] wr_rd = (dut.reg_write && dut.rd_addr != 5'd0) ? dut.rd_addr : 5'd0;

  initial begin
    #1;                      // wait a tiny bit so the instruction memory finishes its own loading first
    if (!$value$plusargs("prog=%s", prog_file)) begin
      $display("give a program with +prog=file.hex");
      $finish;
    end
    $readmemh(prog_file, dut.imem.mem);
    reset = 1;
    repeat (2) @(posedge clk);
    reset = 0;
  end

  // one line per tick, on the falling edge so everything has settled
  // C pc instr rd value store_on store_address store_data
  always @(negedge clk) begin
    if (!reset) begin
      $display("C %08h %08h %0d %08h %0d %08h %08h",
               dut.pc, dut.instr, wr_rd, dut.reg_wd, dut.mem_write, dut.alu_result, dut.rd2);
      if (dut.instr == 32'h00000063) begin      // beq x0,x0,0 jumps to itself, thats our halt
        $display("HALT");
        $finish;
      end
    end
  end

  // safety stop in case a program never halts
  initial begin
    #200000;
    $display("TIMEOUT");
    $finish;
  end
endmodule
