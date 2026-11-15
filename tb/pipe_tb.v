// testbench for the pipelined cpu
// essentially runs one of four programs on cpu_pipe and checks the registers and memory when it finishes
// pick the program with +test=N:   0 = loop (5+4+3+2+1)   1 = multiply (6x7)   2 = new instructions   3 = hazards (forwarding, stall, flush)
//   iverilog -o pipe_sim rtl/*.v tb/pipe_tb.v
//   vvp pipe_sim +test=3
// add +trace to print what the pipeline is doing every tick
module pipe_tb;
  reg  clk = 0;              // the clock, made by the testbench, starts at 0
  reg  reset;                // the restart switch
  integer errors = 0;        // a counter for how many checks failed
  integer test = 0;          // which program to run, comes from +test=N
  reg [1023:0] prog_file;    // basically holds the name of the program file

  // basically creates a copy of the pipelined cpu called dut (device under test)
  cpu_pipe #(.PROG_FILE("tb/cpu_prog.hex")) dut(.clk(clk), .reset(reset));

  always #5 clk = ~clk;      // clock flips every 5 units giving a full cycle every 10

  // reusable routine: u give it the value we got and the value u expect, it prints fail if they are different
  task check(input [255:0] what, input [31:0] got, input [31:0] expected);
    begin
      if (got !== expected) begin
        $display("FAIL %0s: got %0h expected %0h", what, got, expected);
        errors = errors + 1;     // add one to the number of fails
      end
    end
  endtask

  initial begin
    $dumpfile("pipe.vcd"); $dumpvars(0, pipe_tb);   // saves every signal so gtkwave can show it

    if (!$value$plusargs("test=%d", test)) test = 0;
    case (test)
      0: prog_file = "tb/cpu_prog.hex";
      1: prog_file = "tb/mult_prog.hex";
      2: prog_file = "tb/ext_prog.hex";
      default: prog_file = "tb/hazard_prog.hex";
    endcase

    reset = 1;
    #1 $readmemh(prog_file, dut.imem.mem);   // wait a tiny bit so the instruction memory finishes its own loading, then load our program
    repeat (2) @(posedge clk);               // hold reset for two ticks so the whole line starts empty
    #1 reset = 0;                            // reset off, the program runs
    repeat (80) @(posedge clk);              // plenty of ticks to finish and sit in the halt loop
    #1;

    // the registers and memory should end up the same as the single cycle cpu got, just reached through the assembly line
    case (test)
      0: begin
        check("x1", dut.rf.regs[1], 0);
        check("x2", dut.rf.regs[2], 15);       // 5 + 4 + 3 + 2 + 1
        check("x3", dut.rf.regs[3], 15);       // loaded back from memory
        check("mem0", dut.dmem.mem[0], 15);
      end
      1: begin
        check("x2", dut.rf.regs[2], 42);       // 6 x 7
        check("x3", dut.rf.regs[3], 42);
        check("x4", dut.rf.regs[4], 7);
        check("mem0", dut.dmem.mem[0], 42);
      end
      2: begin
        check("x3", dut.rf.regs[3], 8);        // and
        check("x4", dut.rf.regs[4], 14);       // or
        check("x5", dut.rf.regs[5], 32'h14);   // jal saved pc + 4
        check("x6", dut.rf.regs[6], 0);        // skipped by jal
        check("x7", dut.rf.regs[7], 0);        // bne countdown finished
        check("mem0", dut.dmem.mem[0], 8);
      end
      default: begin
        check("x1", dut.rf.regs[1], 5);
        check("x2", dut.rf.regs[2], 8);        // needed x1 right away, forwarding
        check("x3", dut.rf.regs[3], 13);       // needed x2 and x1 right away, forwarding from two spots
        check("mem0", dut.dmem.mem[0], 13);    // sw stored x3 right after it was made
        check("x4", dut.rf.regs[4], 13);       // lw read it back
        check("x5", dut.rf.regs[5], 26);       // needed x4 right after lw, this one needs the stall
        check("x6", dut.rf.regs[6], 21);
        check("x7", dut.rf.regs[7], 0);        // the two instructions after the taken beq and jal got flushed, so x7 never got 99 or 98
        check("x8", dut.rf.regs[8], 32'h28);   // jal saved pc + 4
        check("x9", dut.rf.regs[9], 7);        // the program got all the way to the end
      end
    endcase

    // if nothing failed print all tests passed, otherwise print how many failed
    if (errors == 0) $display("ALL TESTS PASSED (test %0d)", test);
    else $display("%0d TESTS FAILED (test %0d)", errors, test);
    $finish;
  end

  // optional: print what the front of the line and the stall and flush are doing every tick
  always @(negedge clk) if ($test$plusargs("trace") && !reset)
    $display("pc=%08h  in ID=%08h  stall=%b  wrong_guess=%b  fwd_a=%b fwd_b=%b", dut.pc, dut.if_id_instr, dut.stall, dut.mispredict, dut.fwd_a, dut.fwd_b);
endmodule
