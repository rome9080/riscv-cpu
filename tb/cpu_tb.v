// testbench for the whole cpu
// essentially gives it a clock and a reset, lets the program run, and checks the registers and memory along the way
module cpu_tb;
  reg  clk = 0;              // the clock, made by the testbench, starts at 0
  reg  reset;                // the restart switch, the testbench turns it on and off
  integer errors = 0;        // a counter for how many checks failed

  // basically creates a copy of the whole cpu called dut (device under test)
  // and tells it to load its program from tb/cpu_prog.hex
  cpu #(.PROG_FILE("tb/cpu_prog.hex")) dut(.clk(clk), .reset(reset));

  always #5 clk = ~clk;      // clock flips every 5 units giving a full cycle every 10

  // these just copy values from inside the cpu out to wires here so we can check them and see them in gtkwave
  // dont rename the blocks inside cpu.v (rf and dmem) or these lines will break
  wire [31:0] pc   = dut.pc;               // which instruction we are on
  wire [31:0] instr = dut.instr;           // the instruction itself
  wire [31:0] x0   = dut.rf.regs[0];       // register 0, should always be 0
  wire [31:0] x1   = dut.rf.regs[1];       // register 1, the counter in our program
  wire [31:0] x2   = dut.rf.regs[2];       // register 2, the running sum in our program
  wire [31:0] x3   = dut.rf.regs[3];       // register 3, where the answer gets loaded back at the end
  wire [31:0] mem0 = dut.dmem.mem[0];      // slot 0 of data memory, where the sum gets stored

  // reusable routine: wait for n clock ticks, then wait a tiny bit more so everything has settled
  task step(input integer n);
    begin
      repeat (n) @(posedge clk);
      #1;
    end
  endtask

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
    $dumpfile("cpu.vcd"); $dumpvars(0, cpu_tb);   // saves every signal so gtkwave can show it

    // start: reset is on for one tick so the pc goes to 0
    reset = 1;
    step(1);
    check(pc, 32'h00);                // the pc is at the first instruction
    reset = 0;                        // reset off, now the program runs, one instruction per tick

    // after 3 instructions: addi, addi, then beq which is not taken because the counter is 5
    step(3);
    check(pc, 32'h0C);                // beq did not jump so the pc moved on to the add
    check(x1, 5);                     // counter is 5
    check(x2, 0);                     // sum is still 0

    // after 3 more: add, addi, then the beq at the bottom of the loop which always jumps back
    step(3);
    check(pc, 32'h08);                // jumped back up to the top of the loop
    check(x1, 4);                     // counter went down to 4
    check(x2, 5);                     // sum is 5

    // give it plenty of ticks to finish the whole loop, store the sum, load it back, and sit in the halt loop
    step(30);
    check(pc, 32'h20);                // stuck on the last instruction (the halt)
    check(x1, 0);                     // counter counted all the way down to 0
    check(x2, 15);                    // 5 + 4 + 3 + 2 + 1 = 15
    check(mem0, 15);                  // sw stored the sum in memory
    check(x3, 15);                    // lw loaded it back into register 3
    check(x0, 0);                     // register 0 never changed

    // if nothing failed print all tests passed, otherwise print how many failed
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule