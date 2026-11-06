module regfile(
  input clk, /*one bit clock input: tells regfile when to store data*/
  input we,/*tells reg file weather a tick should be stored or not*/
  input [4:0] ra1, ra2, /*two 5 bit inputs that read address, they say which two registers to fetch. there are two because alu uses 2 inputs at once*/
  input [4:0] wa, /*tells cpu where the answer goes in the regfile*/
  input [31:0] wd, /*its the number itself that is going to be stored, its comes from the alu's result*/
  output[31:0] rd1, rd2 /*hands two stored numbs to the alu which feeds it into a and b inputs*/
);
  reg[31:0] regs [0:31]; /*builds 32 registers (each 32 flipflops) width and indext is shown*/
  integer i;
  initial begin
    for (i = 0; i < 32; i = i + 1) regs[i] = 32'd0; /*basically set all registors to 0 at the start of program*/
  end

  always @(posedge clk) begin
    if (we && wa != 5'd0)
      regs[wa] <= wd;
      /*on every clock tick, if we is turned on and wa isnt 0, put wd into the register at wa. if wa is 0, do nothing because register 0 is always 0*/
  end

  assign rd1 = (ra1 == 5'd0) ? 32'd0 : regs[ra1];
  assign rd2 = (ra2 == 5'd0) ? 32'd0 : regs[ra2];
  /* essentially output whatever is in ra1, ra2 but if asked for locker 0 then output 0 instead of the register value because register 0 is always 0*/

endmodule