// data memory: basically the storage for the programs data, the register file only holds 32 numbers so anything bigger goes here
// sw writes a number into it and lw reads a number out of it
module data_mem(
  input         clk,         // clock: tells the memory when its allowed to store something, same job as in the register file
  input         we,          // write enable: 1 means store the number on this tick, 0 means dont, only sw turns this on (the control unit does that later)
  input  [31:0] addr,        // the address we want to read or write, the alu works it out (register + constant) and sends it here
  input  [31:0] wd,          // write data: the number to store, for sw this is the value coming out of the register file
  output [31:0] rd           // read data: the number stored at addr, for lw this goes back into the register file
);

  reg [31:0] mem [0:63];     // 64 slots that each hold one 32 bit number, same idea as the register file array but bigger
  integer i;

  initial begin
    for (i = 0; i < 64; i = i + 1) mem[i] = 32'd0;   // basically set every slot to 0 at the start so nothing is unknown
  end

  // writing only happens on a clock tick and only if we is on
  // addr[7:2] is the same trick as the instruction memory: addresses go up by 4 but the slots are numbered 0, 1, 2, 3
  always @(posedge clk) begin
    if (we)
      mem[addr[7:2]] <= wd;  // put wd into the slot that addr points at
  end

  // reading is instant, no clock needed, same as the register file reads
  assign rd = mem[addr[7:2]];

endmodule