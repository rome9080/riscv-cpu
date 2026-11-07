// cpu: basically the top level file that plugs all 7 blocks together into one working cpu
// it runs one whole instruction every clock tick, this is called a single cycle cpu
// the only new things in here are wires, two selectors (muxes), an adder for pc + 4 and the branch decision
module cpu #(
  parameter PROG_FILE = "program.hex"   // the hex file that holds the program, it gets passed down to the instruction memory
)(
  input clk,                            // the clock, every tick the cpu finishes one instruction
  input reset                           // 1 means send the pc back to address 0 so the program starts from the beginning
);

  // ---------- the wires ----------
  // a wire is basically just a named connection that carries a signal from one block to another
  wire [31:0] pc;            // the address of the instruction we are on, comes out of the program counter
  wire [31:0] next_pc;       // the address the pc will move to on the next tick
  wire [31:0] instr;         // the 32 bit instruction we are running, comes out of the instruction memory
  wire [31:0] imm;           // the constant hiding inside the instruction, comes out of the immediate generator
  wire [31:0] rd1, rd2;      // the two numbers read out of the register file
  wire [31:0] alu_b;         // what actually goes into the alus b input, either rd2 or the constant
  wire [31:0] alu_result;    // the alu answer
  wire        zero;          // 1 when the alu answer is 0, thats how beq knows the two numbers were equal
  wire [31:0] mem_rd;        // the number read out of data memory
  wire [31:0] reg_wd;        // the number that gets saved in the register file, either the alu answer or mem_rd

  // the switches that come out of the control unit
  wire        reg_write, alu_src, mem_write, mem_to_reg, branch;
  wire [3:0]  alu_op;

  // ---------- cutting up the instruction ----------
  // every instruction is 32 bits and the pieces always sit in the same spots, so we just grab them by bit position
  wire [6:0] opcode   = instr[6:0];     // what kind of instruction this is
  wire [4:0] rd_addr  = instr[11:7];    // which register the answer gets saved in
  wire [2:0] funct3   = instr[14:12];   // tells apart instructions of the same kind
  wire [4:0] rs1      = instr[19:15];   // which register is the first number
  wire [4:0] rs2      = instr[24:20];   // which register is the second number
  wire       funct7_5 = instr[30];      // the bit that tells add and sub apart

  // ---------- deciding where the pc goes next ----------
  // normally it just moves forward one instruction (4 bytes)
  // but if this is a branch and the alu says the two numbers were equal then it jumps by the constant instead
  wire [31:0] pc_plus4      = pc + 32'd4;                       // the next instruction in order
  wire [31:0] branch_target = pc + imm;                         // where a branch would jump to
  wire        take_branch   = branch & zero;                    // only jump if its a branch and the numbers were equal
  assign next_pc = take_branch ? branch_target : pc_plus4;      // selector: pick the jump or pick the next one

  // ---------- the 7 blocks ----------
  // each line basically makes one copy of a block and connects its pins by name

  // the pc holds the address of the current instruction
  program_counter pc_reg(.clk(clk), .reset(reset), .next_pc(next_pc), .pc(pc));

  // the instruction memory hands back the instruction stored at that address
  instr_mem #(.INIT_FILE(PROG_FILE)) imem(.addr(pc), .instr(instr));

  // the control unit reads the opcode and flips the switches for everything else
  control_unit ctrl(
    .opcode(opcode), .funct3(funct3), .funct7_5(funct7_5),
    .reg_write(reg_write), .alu_src(alu_src), .alu_op(alu_op),
    .mem_write(mem_write), .mem_to_reg(mem_to_reg), .branch(branch)
  );

  // the immediate generator pulls the constant out of the instruction
  imm_gen immg(.instr(instr), .imm(imm));

  // the register file reads two registers and saves the answer back into one
  regfile rf(
    .clk(clk), .we(reg_write),
    .ra1(rs1), .ra2(rs2), .wa(rd_addr), .wd(reg_wd),
    .rd1(rd1), .rd2(rd2)
  );

  // selector in front of the alu: a register for add, sub and beq, or the constant for addi, lw and sw
  assign alu_b = alu_src ? imm : rd2;

  // the alu does the math
  alu alu_unit(.a(rd1), .b(alu_b), .op(alu_op), .result(alu_result), .zero(zero));

  // the data memory, the alu answer is the address and for sw the number to store is the second register
  data_mem dmem(.clk(clk), .we(mem_write), .addr(alu_result), .wd(rd2), .rd(mem_rd));

  // selector in front of the register file: the alu answer for most instructions, the memory number for lw
  assign reg_wd = mem_to_reg ? mem_rd : alu_result;

endmodule