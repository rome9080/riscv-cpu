//the pc is the program counter, it keeps tract of where cpu is in the program holds addresses as there being run and moves on to next after each instruction
module program_counter(
  input         clk,        // clock tells pc when its allowed to change, it gives exact moment to update
  input         reset,      // tells pc when to start over from the beginning
  input  [31:0] next_pc,    // its the next pc, basically tells pc where to go next
  output reg [31:0] pc      // the pc that is being read. current instruction address
);

  always @(posedge clk) begin
    if (reset)
      pc <= 32'd0;          // restart from the beginning
    else
      pc <= next_pc;        // otherwise move to the next address
  end
//basically tells pc when to restart and when to move to next adress based on reset bit
endmodule