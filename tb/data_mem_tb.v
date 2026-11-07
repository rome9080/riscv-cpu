// testbench for the data memory
// essentially writes a few numbers in, reads them back, and checks that each one is what we put in
module data_mem_tb;
  reg         clk = 0;       // the clock, made by the testbench, starts at 0
  reg         we;            // write enable, the testbench turns it on and off
  reg  [31:0] addr;          // the address we want to read or write
  reg  [31:0] wd;            // the number we want to store
  wire [31:0] rd;            // the number that comes out, the testbench only watches this
  integer errors = 0;        // a counter for how many checks failed

  // basically creates a copy of the data memory called dut (device under test)
  data_mem dut(.clk(clk), .we(we), .addr(addr), .wd(wd), .rd(rd));

  always #5 clk = ~clk;      // clock flips every 5 units giving a full cycle every 10

  // reusable routine: u give it an address and a number, it stores the number there on the next clock tick
  task write_word(input [31:0] a, input [31:0] d);
    begin
      we = 1; addr = a; wd = d;   // turn write on and set up the address and the number
      @(posedge clk);             // wait for the clock tick, thats when it actually gets stored
      #1 we = 0;                  // then turn write off again
    end
  endtask

  // reusable routine: u give it an address and the number u expect, it prints fail if the memory holds something else
  task read_check(input [31:0] a, input [31:0] expected);
    begin
      addr = a;                   // ask for this address
      #1;                         // wait a tiny bit for the answer to come out
      if (rd !== expected) begin
        $display("FAIL: addr %0h got %0h expected %0h", a, rd, expected);
        errors = errors + 1;      // add one to the number of fails
      end
    end
  endtask

  initial begin
    $dumpfile("data_mem.vcd"); $dumpvars(0, data_mem_tb);   // saves every signal so gtkwave can show it
    we = 0; addr = 0; wd = 0;                               // starting values so nothing is unknown

    // test 1: a fresh memory should be all zeros
    read_check(32'h00, 32'h00000000);
    read_check(32'h10, 32'h00000000);

    // test 2: write three numbers then read them back
    write_word(32'h00, 100);
    write_word(32'h04, 200);
    write_word(32'hFC, 32'hDEADBEEF);   // the very last slot
    read_check(32'h00, 100);
    read_check(32'h04, 200);
    read_check(32'hFC, 32'hDEADBEEF);

    // test 3: write enable off, new data is on the pins but nothing should get stored
    we = 0; addr = 32'h04; wd = 555;
    @(posedge clk); #1;
    read_check(32'h04, 200);            // still 200, not 555

    // test 4: overwrite one slot and make sure the others didnt change
    write_word(32'h04, 7);
    read_check(32'h04, 7);              // slot 1 changed to 7
    read_check(32'h00, 100);            // slot 0 is still 100

    // test 5: a slot we never wrote to should still be 0
    read_check(32'h08, 32'h00000000);

    // if nothing failed print all tests passed, otherwise print how many failed
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule