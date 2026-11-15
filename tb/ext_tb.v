// testbench for the new instructions (and, or, bne, jal)
// essentially runs tb/ext_prog.hex on the whole cpu and checks the registers and memory at the end
module ext_tb;
  reg  clk = 0;              // the clock, made by the testbench, starts at 0
  reg  reset;                // the restart switch
  integer errors = 0;        // a counter for how many checks failed

  // basically creates a copy of the whole cpu called dut, loading the new instruction program
  cpu #(.PROG_FILE("tb/ext_prog.hex")) dut(.clk(clk), .reset(reset));

  always #5 clk = ~clk;      // clock flips every 5 units giving a full cycle every 10

  // reusable routine: u give it the value we got and the value u expect, it prints fail if they are different
  task check(input [31:0] got, input [31:0] expected);
    begin
      if (got !== expected) begin
        $display("FAIL at time %0d: got %0h expected %0h", $time, got, expected);
        errors = errors + 1;     // add one to the number of fails
      end
    end
  endtask

  initial begin
    $dumpfile("ext.vcd"); $dumpvars(0, ext_tb);   // saves every signal so gtkwave can show it

    reset = 1;
    repeat (2) @(posedge clk);    // hold reset for two ticks so the pc starts at 0
    #1 reset = 0;                 // reset off, the program runs
    repeat (40) @(posedge clk);   // plenty of ticks to finish and sit in the halt loop
    #1;

    check(dut.pc, 32'h28);             // stuck on the halt instruction at the end
    check(dut.rf.regs[1], 12);         // 1100 in binary
    check(dut.rf.regs[2], 10);         // 1010 in binary
    check(dut.rf.regs[3], 8);          // and: 1100 and 1010 = 1000 = 8
    check(dut.rf.regs[4], 14);         // or:  1100 or  1010 = 1110 = 14
    check(dut.rf.regs[5], 32'h14);     // jal saved pc + 4 (the way back) in x5
    check(dut.rf.regs[6], 0);          // the instruction right after jal was skipped, so x6 never got 99
    check(dut.rf.regs[7], 0);          // bne looped the countdown 3 to 0 and then stopped looping
    check(dut.dmem.mem[0], 8);         // sw stored the and answer in memory

    // if nothing failed print all tests passed, otherwise print how many failed
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule
