// testbench for the immediate generator
// essentially feeds it real instructions and checks the constant that comes out
module imm_gen_tb;
  reg  [31:0] instr;         // the instruction we feed in, the testbench controls this
  wire [31:0] imm;           // the constant that comes out, the testbench only watches this
  integer errors = 0;        // a counter for how many checks failed

  // basically creates a copy of the immediate generator called dut (device under test)
  imm_gen dut(.instr(instr), .imm(imm));

  // reusable routine: u give it an instruction and the constant u expect
  task check(input [31:0] i, input [31:0] expected);
    begin
      instr = i;                 // feed in this instruction
      #1;                        // wait a tiny bit for the answer to come out
      if (imm !== expected) begin
        $display("FAIL: instr %0h got %0h expected %0h", i, imm, expected);
        errors = errors + 1;     // add one to the number of fails
      end
      #9;                        // wait a bit more so the waveform is easy to read
    end
  endtask

  initial begin
    $dumpfile("imm_gen.vcd"); $dumpvars(0, imm_gen_tb);   // saves every signal so gtkwave can show it

    // i-type tests, the constant is in the top 12 bits
    check(32'h00500093, 32'h00000005);   // addi x1, x0, 5      the constant is 5
    check(32'hFFF00093, 32'hFFFFFFFF);   // addi x1, x0, -1     negative so it fills the top with ones
    check(32'h7FF00093, 32'h000007FF);   // addi x1, x0, 2047   biggest positive, stays positive
    check(32'h80000093, 32'hFFFFF800);   // addi x1, x0, -2048  smallest negative
    check(32'h0080A183, 32'h00000008);   // lw x3, 8(x1)        the constant is the offset 8

    // s-type tests, the constant is split in two pieces
    check(32'h0020A623, 32'h0000000C);   // sw x2, 12(x1)       offset 12
    check(32'hFE20AE23, 32'hFFFFFFFC);   // sw x2, -4(x1)       negative offset -4

    // b-type tests, the constant is scattered
    check(32'h00208463, 32'h00000008);   // beq x1, x2, 8       jump forward 8
    check(32'hFE208CE3, 32'hFFFFFFF8);   // beq x1, x2, -8      jump back 8

    // no constant
    check(32'h002081B3, 32'h00000000);   // add x3, x1, x2      add has no constant so 0

    // if nothing failed print all tests passed, otherwise print how many failed
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule