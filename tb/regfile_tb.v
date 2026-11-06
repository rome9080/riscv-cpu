module regfile_tb;
  reg         clk = 0;
  reg         we;
  reg  [4:0]  ra1, ra2, wa;
  reg  [31:0] wd;
  wire [31:0] rd1, rd2;
  integer errors = 0;// a counter for failed

  regfile dut(.clk(clk), .we(we), .ra1(ra1), .ra2(ra2),
              .wa(wa), .wd(wd), .rd1(rd1), .rd2(rd2));
   //essentially creates a copy of register file called dut (device under test)

  always #5 clk = ~clk;//clock flips every 5 units giving full cycle ever 10

  task write_reg(input [4:0] addr, input [31:0] data);
    begin
      we = 1; wa = addr; wd = data;
      @(posedge clk);
      #1 we = 0;
      /*register number reusable routine that will write a number into the register*/
    end
  endtask

  task read_check(input [4:0] a1, input [31:0] e1,
                  input [4:0] a2, input [31:0] e2);
    begin
      ra1 = a1; ra2 = a2;
      #1;
      if (rd1 !== e1) begin
        $display("FAIL: read x%0d got %0h expected %0h", a1, rd1, e1);
        errors = errors + 1;
      end
      if (rd2 !== e2) begin
        $display("FAIL: read x%0d got %0h expected %0h", a2, rd2, e2);
        errors = errors + 1;
      end
    end
        /*this helper reads two registors and checks if they hold the number u
        put in it. if the number is the same it passes others wise it prints fail*/
  endtask

  initial begin
    $dumpfile("regfile.vcd"); $dumpvars(0, regfile_tb);
    we = 0; ra1 = 0; ra2 = 0; wa = 0; wd = 0;

    write_reg(1, 100);
    write_reg(2, 200);
    write_reg(5, 32'hDEADBEEF);
    read_check(1, 100, 2, 200);
    read_check(5, 32'hDEADBEEF, 1, 100);

    write_reg(0, 999);
    read_check(0, 0, 0, 0);

    we = 0; wa = 1; wd = 555;
    @(posedge clk); #1;
    read_check(1, 100, 2, 200);

    write_reg(1, 7);
    read_check(1, 7, 2, 200);

    read_check(31, 0, 30, 0);

    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d TESTS FAILED", errors);
    $finish;
    /*test script made that store a few number in reg files slot, reads them back and
    checks that each math what is put in. also makes sure register zero is empty
    it passes silently but prints fail if it fails at the end all tests passed is shown if alls good*/
  end
endmodule