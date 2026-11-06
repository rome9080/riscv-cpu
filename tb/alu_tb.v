module alu_tb;
  reg  [31:0] a, b;
  reg  [3:0]  op; 
  //these are the inputs for out alu
  wire [31:0] result;
  wire zero;
  //the alu outputs 
  integer errors = 0;
  //counter that counts failed checks goes up by one each time a check fails

  alu dut(a, b, op, result, zero);
  //creates one alu and connects its pins above
  task check(input [31:0] expected);
  //check defines a reusable routine. it preforms a comparison

    begin
      #1;
      if (result !== expected) begin
        $display("FAIL: op=%b a=%0d b=%0d got=%0d expected=%0d", op, a, b, result, expected);
        errors = errors + 1;
        //if result is diff them what i wanted end

      end
    end
  endtask

  initial begin
    $dumpfile("alu.vcd"); $dumpvars(0, alu_tb);
    //these lines exist for the waveform, names and tells it what to record
    a = 10; b = 3; //two inputs are set
    op = 4'b0000; check(13);
    op = 4'b0001; check(7);
    op = 4'b0010; check(2);
    op = 4'b0011; check(11);
    op = 4'b0100; check(9);
    op = 4'b0111; check(0);
    //tests every arithmetic in alu 
    a = 5; b = 2; op = 4'b0101; check(20);
    op = 4'b0110; check(1);
    //tests shifting
    if (errors == 0) $display("ALL TESTS PASSED");
    //lets u know it works
    else $display("%0d TESTS FAILED", errors);
    $finish;
  end
endmodule