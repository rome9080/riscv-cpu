// testbench for the instruction memory
// essentially asks for a few addresses and checks the right instruction comes back
module instr_mem_tb;
  reg  [31:0] addr;         // the address we ask for, the testbench controls this
  wire [31:0] instr;        // the instruction that comes out, the testbench only watches this
  integer errors = 0;       // a counter for how many checks failed

  // basically creates a copy of the instruction memory called dut (device under test)
  // and tells it to load its program from tb/test_prog.hex
  instr_mem #(.INIT_FILE("tb/test_prog.hex")) dut(.addr(addr), .instr(instr));

  // reusable routine: u give it an address and the instruction u expect
  task check(input [31:0] a, input [31:0] expected);
    begin
      addr = a;                  // ask for this address
      #1;                        // wait a tiny bit for the answer to come out
      if (instr !== expected) begin
        $display("FAIL: addr %0h got %0h expected %0h", a, instr, expected);
        errors = errors + 1;     // add one to the number of fails
      end
      #9;                        // wait a bit more so the waveform is easy to read
    end
  endtask

  initial begin
    $dumpfile("instr_mem.vcd"); $dumpvars(0, instr_mem_tb);   // saves every signal so gtkwave can show it

    check(32'h00, 32'h00500093);    // slot 0, the first instruction
    check(32'h04, 32'h00300113);    // slot 1
    check(32'h08, 32'h002081B3);    // slot 2
    check(32'h0C, 32'h40118233);    // slot 3
    check(32'h10, 32'h00000000);    // past the end of the program so it should be 0
    check(32'hFC, 32'h00000000);    // the very last slot, also 0
    check(32'h00, 32'h00500093);    // back to the start, it should still give the same answer

    // if nothing failed print all tests passed, otherwise print how many failed
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule