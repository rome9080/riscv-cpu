module alu_tb;
  reg  [31:0] a, b;
  reg  [3:0]  op;
  wire [31:0] result;
  wire zero;
  integer errors = 0;

  alu dut(a, b, op, result, zero);

  task check(input [31:0] expected);
    begin
      #1;
      if (result !== expected) begin
        $display("FAIL: op=%b a=%0d b=%0d got=%0d expected=%0d", op, a, b, result, expected);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    $dumpfile("alu.vcd"); $dumpvars(0, alu_tb);
    a = 10; b = 3;
    op = 4'b0000; check(13);
    op = 4'b0001; check(7);
    op = 4'b0010; check(2);
    op = 4'b0011; check(11);
    op = 4'b0100; check(9);
    op = 4'b0111; check(0);
    a = 5; b = 2; op = 4'b0101; check(20);
    op = 4'b0110; check(1);
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule