// instruction memory: basically the storage that holds the program
// the pc gives an address and this hands back the 32 bit instruction stored there
module instr_mem #(
  parameter INIT_FILE = "program.hex"   // a setting: the name of the file that holds the program, can be changed when the block is used
)(
  input  [31:0] addr,       // the address of the instruction we want, it comes from the pc
  output [31:0] instr       // the 32 bit instruction stored at that address, goes to the control unit later
);

  reg [31:0] mem [0:63];    // 64 slots that each hold one 32 bit instruction, so programs up to 64 instructions
  integer i;

  initial begin
    for (i = 0; i < 64; i = i + 1) mem[i] = 32'd0;   // basically set every slot to 0 at the start
    $readmemh(INIT_FILE, mem);                       // then load the program from the hex file, line 1 goes in slot 0, line 2 in slot 1 and so on
  end

  // each instruction is 4 bytes so addresses go 0, 4, 8, 12 but the slots are numbered 0, 1, 2, 3
  // addr[7:2] drops the bottom 2 bits which is the same as dividing by 4, that turns the address into the slot number
  // no clock needed, it just reads instantly like the register file reads
  assign instr = mem[addr[7:2]];

endmodule