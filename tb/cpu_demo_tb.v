// demo testbench for the whole cpu
// essentially runs a program and prints one line per instruction so u can watch the cpu work
// run the default program:   vvp cpu_demo_sim
// run another program:       vvp cpu_demo_sim +prog=tb/mult_prog.hex
module cpu_demo_tb;
  reg  clk = 0;              // the clock, made by the testbench, starts at 0
  reg  reset;                // the restart switch
  reg  [1023:0] prog_file;   // basically holds the name of the program file to load

  // basically creates a copy of the whole cpu called dut
  // the program file name is filled in below before the cpu loads it
  cpu #(.PROG_FILE("tb/cpu_prog.hex")) dut(.clk(clk), .reset(reset));

  always #5 clk = ~clk;      // clock flips every 5 units giving a full cycle every 10

  // these copy values from inside the cpu out to wires here so we can print them
  wire [31:0] pc    = dut.pc;
  wire [31:0] instr = dut.instr;
  wire [31:0] x1    = dut.rf.regs[1];
  wire [31:0] x2    = dut.rf.regs[2];
  wire [31:0] x3    = dut.rf.regs[3];
  wire [31:0] mem0  = dut.dmem.mem[0];

  // reusable routine: turns the instruction into a name so the printout is readable
  // the opcode is the bottom 7 bits of the instruction
  function [47:0] name(input [31:0] i);
    begin
      case (i[6:0])
        7'b0010011: name = "addi  ";
        7'b0110011: name = (i[14:12] == 3'b111) ? "and   " :
                           (i[14:12] == 3'b110) ? "or    " :
                           (i[30])               ? "sub   " : "add   ";
        7'b0000011: name = "lw    ";
        7'b0100011: name = "sw    ";
        7'b1100011: name = (i[14:12] == 3'b001) ? "bne   " : "beq   ";
        7'b1101111: name = "jal   ";
        default:    name = "???   ";
      endcase
    end
  endfunction

  initial begin
    // if u gave +prog=somefile.hex then load that file into the instruction memory
    #1;   // wait a tiny bit so the instruction memory finishes its own loading first
    if ($value$plusargs("prog=%s", prog_file)) $readmemh(prog_file, dut.imem.mem);

    $display("pc        instr      name    x1  x2  x3  mem0");
    reset = 1;
    repeat (2) @(posedge clk);
    reset = 0;
  end

  // prints one line every clock tick, on the falling edge so everything has settled
  // stops when the cpu reaches the halt instruction (beq x0,x0,0 which jumps to itself)
  always @(negedge clk) begin
    if (!reset) begin
      $display("%08h  %08h   %s  %0d   %0d   %0d   %0d", pc, instr, name(instr), x1, x2, x3, mem0);
      if (instr == 32'h00000063) begin
        $display("halted. x2 = %0d, x3 = %0d, mem0 = %0d", x2, x3, mem0);
        $finish;
      end
    end
  end
endmodule
