// control unit: basically the part that reads an instruction and flips the switches for every other block
// it doesnt do any math or store anything itself, it just decides what the other blocks should do for this instruction
module control_unit(
  input  [6:0] opcode,         // the bottom 7 bits of the instruction, tells us what kind of instruction it is (add type, addi, lw, sw or beq)
  input  [2:0] funct3,         // 3 more bits that tell instructions of the same kind apart, like beq vs bne or lw vs lb
  input        funct7_5,       // one bit from the top of the instruction, its how add and sub get told apart because they share everything else
  output reg       reg_write,  // 1 means save the answer in a register, goes to the we input of the register file
  output reg       alu_src,    // picks what goes into the alus b input: 0 = a register, 1 = the constant from the immediate generator
  output reg [3:0] alu_op,     // picks what the alu does, uses the same codes as alu.v (0 = add, 1 = sub)
  output reg       mem_write,  // 1 means store a number in data memory, goes to the we input of the data memory, only sw turns this on
  output reg       mem_to_reg, // picks what gets saved in the register: 0 = the alu answer, 1 = the number read from data memory (lw)
  output reg       branch      // 1 means this is a branch, if the alu says the two numbers were equal the pc jumps instead of adding 4
);

  // no clock needed, it works out the answer instantly like the alu
  always @(*) begin
    // start with everything turned off, then each instruction only turns on what it needs
    // this also means an instruction we dont support (or an empty slot of all 0s) does nothing instead of breaking something
    reg_write  = 1'b0;
    alu_src    = 1'b0;
    alu_op     = 4'b0000;
    mem_write  = 1'b0;
    mem_to_reg = 1'b0;
    branch     = 1'b0;

    case (opcode)
      7'b0110011: begin                  // r-type: add and sub, both numbers come from registers
        // glue funct7_5 and funct3 together into one 4 bit number so one case can pick between them
        case ({funct7_5, funct3})
          4'b0_000: begin                // add
            reg_write = 1'b1;            // save the answer in a register
            alu_op    = 4'b0000;         // alu adds
          end
          4'b1_000: begin                // sub
            reg_write = 1'b1;            // save the answer in a register
            alu_op    = 4'b0001;         // alu subtracts
          end
          default: begin end             // any other r-type (and, or and so on) isnt supported yet so do nothing
        endcase
      end

      7'b0010011: begin                  // addi: a register plus a constant
        if (funct3 == 3'b000) begin      // only addi for now, the other math with constants (andi, ori) share this opcode
          reg_write = 1'b1;              // save the answer in a register
          alu_src   = 1'b1;              // alu b input is the constant, not a register
          alu_op    = 4'b0000;           // alu adds
        end
      end

      7'b0000011: begin                  // lw: load a number from data memory into a register
        if (funct3 == 3'b010) begin      // 010 means a whole 32 bit word, the smaller loads (lb, lh) arent supported yet
          reg_write  = 1'b1;             // save the number in a register
          alu_src    = 1'b1;             // alu b input is the constant (the offset)
          alu_op     = 4'b0000;          // alu adds register + offset to get the memory address
          mem_to_reg = 1'b1;             // the number saved comes from data memory, not the alu answer
        end
      end

      7'b0100011: begin                  // sw: store a register into data memory
        if (funct3 == 3'b010) begin      // whole 32 bit word again
          alu_src   = 1'b1;              // alu b input is the constant (the offset)
          alu_op    = 4'b0000;           // alu adds register + offset to get the memory address
          mem_write = 1'b1;              // tell the data memory to store the number
        end                              // reg_write stays 0 because sw doesnt save anything in a register
      end

      7'b1100011: begin                  // beq: branch if the two registers are equal
        if (funct3 == 3'b000) begin      // 000 is beq, bne has a different funct3 so it wont match
          alu_op = 4'b0001;              // alu subtracts, if the answer is 0 the numbers were equal (thats the zero flag)
          branch = 1'b1;                 // tell the pc this might be a jump
        end                              // alu_src stays 0 because both numbers come from registers
      end

      default: begin end                 // anything else does nothing
    endcase
  end

endmodule