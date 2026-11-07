// immediate generator: basically finds the constant hiding inside an instruction and turns it into a normal 32 bit number
// the alu cant use the short version so this widens it
module imm_gen(
  input  [31:0] instr,       // the instruction we want the constant from, comes from the instruction memory
  output reg [31:0] imm      // the constant after its widened to 32 bits, goes to the alu later
);

  // the bottom 7 bits of every instruction are the opcode, it tells us what type of instruction it is
  wire [6:0] opcode = instr[6:0];

  // no clock needed, it works out the answer instantly like the alu
  always @(*) begin
    case (opcode)
      7'b0010011, 7'b0000011:    // i-type: addi and lw, the constant is in the top 12 bits
        // copy the top bit (the sign) 20 times then add the 12 constant bits, this is what keeps negative numbers negative
        imm = {{20{instr[31]}}, instr[31:20]};

      7'b0100011:                // s-type: sw, the constant is split in two pieces
        // 20 sign bits, then the top 7 bits, then the bottom 5 bits glued back together
        imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

      7'b1100011:                // b-type: beq, the constant is scattered all over the instruction
        // the bits are out of order so this puts them back, the last 0 is there because a branch distance is always even
        imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

      default:                   // anything else like add has no constant so just give 0
        imm = 32'd0;
    endcase
  end

endmodule