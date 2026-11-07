// testbench for the control unit
// essentially feeds it real instructions and checks that every switch comes out right
module control_unit_tb;
  reg  [31:0] instr;          // the instruction we feed in, the testbench controls this
  wire        reg_write, alu_src, mem_write, mem_to_reg, branch;   // the switches that come out, the testbench only watches these
  wire [3:0]  alu_op;
  integer errors = 0;         // a counter for how many checks failed

  // basically creates a copy of the control unit called dut (device under test)
  // the testbench pulls the opcode, funct3 and funct7_5 bits out of the instruction, the real cpu will do the same
  control_unit dut(
    .opcode(instr[6:0]), .funct3(instr[14:12]), .funct7_5(instr[30]),
    .reg_write(reg_write), .alu_src(alu_src), .alu_op(alu_op),
    .mem_write(mem_write), .mem_to_reg(mem_to_reg), .branch(branch)
  );

  // glues all the switches into one 9 bit number so one check can look at all of them at once
  // the order is: reg_write, alu_src, alu_op (4 bits), mem_write, mem_to_reg, branch
  wire [8:0] ctrl_out = {reg_write, alu_src, alu_op, mem_write, mem_to_reg, branch};

  // reusable routine: u give it an instruction and the switches u expect
  task check(input [31:0] i, input [8:0] expected);
    begin
      instr = i;                 // feed in this instruction
      #1;                        // wait a tiny bit for the answer to come out
      if (ctrl_out !== expected) begin
        $display("FAIL: instr %0h got %b expected %b", i, ctrl_out, expected);
        errors = errors + 1;     // add one to the number of fails
      end
      #9;                        // wait a bit more so the waveform is easy to read
    end
  endtask

  initial begin
    $dumpfile("control_unit.vcd"); $dumpvars(0, control_unit_tb);   // saves every signal so gtkwave can show it

    // the expected numbers are written as reg_write _ alu_src _ alu_op _ mem_write _ mem_to_reg _ branch
    check(32'h002081B3, 9'b1_0_0000_0_0_0);   // add x3, x1, x2      save answer, two registers, alu adds
    check(32'h40118233, 9'b1_0_0001_0_0_0);   // sub x4, x3, x1      same but alu subtracts
    check(32'h00500093, 9'b1_1_0000_0_0_0);   // addi x1, x0, 5      save answer, constant goes in, alu adds
    check(32'h0080A183, 9'b1_1_0000_0_1_0);   // lw x3, 8(x1)        like addi but the saved number comes from memory
    check(32'h0020A623, 9'b0_1_0000_1_0_0);   // sw x2, 12(x1)       nothing saved in a register, memory write on
    check(32'h00208463, 9'b0_0_0001_0_0_1);   // beq x1, x2, 8       nothing saved, alu subtracts, branch on

    // things we dont support yet should do nothing at all
    check(32'h0020F1B3, 9'b0_0_0000_0_0_0);   // and x3, x1, x2      not supported yet so everything stays off
    check(32'h00209463, 9'b0_0_0000_0_0_0);   // bne x1, x2, 8       same opcode as beq but a different funct3 so it does nothing
    check(32'h00000000, 9'b0_0_0000_0_0_0);   // an empty instruction slot, does nothing

    // if nothing failed print all tests passed, otherwise print how many failed
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule