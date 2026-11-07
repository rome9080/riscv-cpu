// pc_tb.v - testbench for the program counter
// a testbench is a virtual lab bench: it makes a clock, pokes the pc, and checks the address

module program_counter_tb;
  reg         clk = 0;      // the clock, made by the testbench, starts at 0
  reg         reset;        // restart switch, the testbench turns it on and off
  reg         jump;         // 1 = jump to 'target' instead of adding 4 (stands in for the control unit)
  reg  [31:0] target;       // the address to jump to
  wire [31:0] pc;           // the pc's output, the testbench only watches this
  integer errors = 0;       // counts how many checks failed

  // this mimics what the full cpu will do: next = jump target, or pc + 4
  // if jump is 1 use target, otherwise move forward one instruction (4 bytes)
  wire [31:0] next_pc = jump ? target : pc + 4;

  // makes one copy of the program counter called dut (device under test)
  program_counter dut(.clk(clk), .reset(reset), .next_pc(next_pc), .pc(pc));

  always #5 clk = ~clk;     // clock flips every 5 units, so a full cycle is 10

  // reusable routine: give it the address you expect, it prints FAIL if the pc is different
  task check(input [31:0] expected);
    begin
      if (pc !== expected) begin
        $display("FAIL: pc got %0h expected %0h", pc, expected);
        errors = errors + 1;     // add one to the failure count
      end
    end
  endtask

  initial begin
    $dumpfile("pc.vcd"); $dumpvars(0, program_counter_tb);   // save every signal for gtkwave
    reset = 1; jump = 0; target = 0;                         // starting values so nothing is unknown

    // each line below waits for a clock edge, waits 1 more unit, then checks the pc
    @(posedge clk); #1; check(0);            // reset puts the pc at 0
    reset = 0;                               // turn reset off, now it can count

    @(posedge clk); #1; check(4);            // 0 -> 4
    @(posedge clk); #1; check(8);            // 4 -> 8
    @(posedge clk); #1; check(12);           // 8 -> 12

    jump = 1; target = 32'h40;               // now jump to address 0x40
    @(posedge clk); #1; check(32'h40);       // the pc lands exactly on the target
    jump = 0;                                // go back to adding 4
    @(posedge clk); #1; check(32'h44);       // 0x40 -> 0x44, it keeps counting from the new place

    reset = 1;                               // reset in the middle of a run
    @(posedge clk); #1; check(0);            // pc snaps back to 0
    reset = 0;
    @(posedge clk); #1; check(4);            // and it counts again

    // print the final result, then stop the simulation
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule