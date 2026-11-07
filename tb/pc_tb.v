// testbench for the program counter
// essentially a virtual lab bench: it makes a clock, pokes the pc, and checks the address

module program_counter_tb;
  reg         clk = 0;      // the clock, made by the testbench, starts at 0
  reg         reset;        // the restart switch, the testbench turns it on and off
  reg         jump;         // 1 = jump to target instead of adding 4 (pretends to be the control unit for now)
  reg  [31:0] target;       // the address to jump to
  wire [31:0] pc;           // the pc output, the testbench only watches this
  integer errors = 0;       // a counter for how many checks failed

  // basically mimics what the full cpu will do later
  // if jump is on go to the target, otherwise move forward one instruction (4 bytes)
  wire [31:0] next_pc = jump ? target : pc + 4;

  // essentially creates a copy of the program counter called dut (device under test)
  program_counter dut(.clk(clk), .reset(reset), .next_pc(next_pc), .pc(pc));

  always #5 clk = ~clk;     // clock flips every 5 units giving a full cycle every 10

  // reusable routine: u give it the address u expect, if the pc is different it prints fail
  task check(input [31:0] expected);
    begin
      if (pc !== expected) begin
        $display("FAIL: pc got %0h expected %0h", pc, expected);
        errors = errors + 1;     // add one to the number of fails
      end
    end
  endtask

  initial begin
    $dumpfile("pc.vcd"); $dumpvars(0, program_counter_tb);   // saves every signal so gtkwave can show it
    reset = 1; jump = 0; target = 0;                         // starting values so nothing is unknown

    // each line below waits for a clock tick, waits a tiny bit more, then checks the pc
    @(posedge clk); #1; check(0);            // reset puts the pc at 0
    reset = 0;                               // turn reset off so it can count

    @(posedge clk); #1; check(4);            // 0 to 4
    @(posedge clk); #1; check(8);            // 4 to 8
    @(posedge clk); #1; check(12);           // 8 to 12

    jump = 1; target = 32'h40;               // now jump to address 40 (hex)
    @(posedge clk); #1; check(32'h40);       // the pc lands exactly on the target
    jump = 0;                                // go back to adding 4
    @(posedge clk); #1; check(32'h44);       // 40 to 44, it keeps counting from the new spot

    reset = 1;                               // reset in the middle of a run
    @(posedge clk); #1; check(0);            // pc goes straight back to 0
    reset = 0;
    @(posedge clk); #1; check(4);            // and it starts counting again

    // if nothing failed print all tests passed, otherwise print how many failed
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule