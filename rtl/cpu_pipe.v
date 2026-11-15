// cpu_pipe: basically the same cpu as cpu.v but built like an assembly line (a pipeline)
// instead of doing one whole instruction per tick, there are 5 stations and 5 different instructions are being worked on at the same time
// the 7 blocks are reused as they are, the new stuff is the walls between stations, forwarding, the stall and the flush
//   IF  = fetch        get the instruction
//   ID  = decode       read registers, make the constant, set the switches
//   EX  = execute      the alu does the math, branches and jumps get decided here
//   MEM = memory       lw and sw talk to data memory
//   WB  = write back   the answer gets saved in a register
module cpu_pipe #(
  parameter PROG_FILE = "program.hex"   // the hex file that holds the program, same as cpu.v
)(
  input clk,                            // the clock, every tick every instruction moves forward one station
  input reset                           // 1 means clear the whole assembly line and send the pc back to 0
);

  // ---------- the walls between stations (pipeline registers) ----------
  // a wall is basically a set of flip flops that holds one instructions stuff for one tick so the next station can use it
  // names go wall_thing, so id_ex_rd1 means "rd1, sitting in the wall between ID and EX"

  // wall 1: IF/ID
  reg [31:0] if_id_pc;         // address of the instruction in the ID station
  reg [31:0] if_id_instr;      // the instruction in the ID station

  // wall 2: ID/EX
  reg [31:0] id_ex_pc;         // address of the instruction in the EX station
  reg [31:0] id_ex_rd1, id_ex_rd2, id_ex_imm;   // its two register numbers and its constant
  reg [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;    // which registers it reads (for forwarding) and which one it will write
  reg        id_ex_reg_write, id_ex_alu_src, id_ex_mem_write, id_ex_mem_to_reg, id_ex_branch, id_ex_bne, id_ex_jump;   // its switches
  reg [3:0]  id_ex_alu_op;

  // wall 3: EX/MEM
  reg [31:0] ex_mem_result;    // the alu answer (or pc + 4 for jal), also the memory address for lw and sw
  reg [31:0] ex_mem_store;     // the number sw will store
  reg [4:0]  ex_mem_rd;
  reg        ex_mem_reg_write, ex_mem_mem_write, ex_mem_mem_to_reg;

  // wall 4: MEM/WB
  reg [31:0] mem_wb_result;    // the alu answer
  reg [31:0] mem_wb_mem_rd;    // the number lw read out of memory
  reg [4:0]  mem_wb_rd;
  reg        mem_wb_reg_write, mem_wb_mem_to_reg;

  // ---------- station 1: IF (fetch) ----------
  wire [31:0] pc, next_pc, instr;
  wire [31:0] pc_plus4 = pc + 32'd4;

  program_counter pc_reg(.clk(clk), .reset(reset), .next_pc(next_pc), .pc(pc));
  instr_mem #(.INIT_FILE(PROG_FILE)) imem(.addr(pc), .instr(instr));

  // ---------- station 2: ID (decode) ----------
  wire [6:0] id_opcode = if_id_instr[6:0];
  wire [4:0] id_rd     = if_id_instr[11:7];
  wire [2:0] id_funct3 = if_id_instr[14:12];
  wire [4:0] id_rs1    = if_id_instr[19:15];
  wire [4:0] id_rs2    = if_id_instr[24:20];
  wire       id_funct7_5 = if_id_instr[30];

  wire        c_reg_write, c_alu_src, c_mem_write, c_mem_to_reg, c_branch, c_bne, c_jump;
  wire [3:0]  c_alu_op;
  wire [31:0] id_imm;
  wire [31:0] rf_rd1, rf_rd2;

  control_unit ctrl(
    .opcode(id_opcode), .funct3(id_funct3), .funct7_5(id_funct7_5),
    .reg_write(c_reg_write), .alu_src(c_alu_src), .alu_op(c_alu_op),
    .mem_write(c_mem_write), .mem_to_reg(c_mem_to_reg), .branch(c_branch), .bne(c_bne), .jump(c_jump)
  );

  imm_gen immg(.instr(if_id_instr), .imm(id_imm));

  // the number that gets saved by the WB station, either the alu answer or the memory number for lw
  wire [31:0] wb_data = mem_wb_mem_to_reg ? mem_wb_mem_rd : mem_wb_result;

  regfile rf(
    .clk(clk), .we(mem_wb_reg_write),
    .ra1(id_rs1), .ra2(id_rs2), .wa(mem_wb_rd), .wd(wb_data),
    .rd1(rf_rd1), .rd2(rf_rd2)
  );

  // the register file only saves on the clock tick, so if WB is saving a register at the same moment ID wants to read it, ID would see the old number
  // this fixes it by handing ID the new number directly
  wire [31:0] id_rd1 = (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_rs1) ? wb_data : rf_rd1;
  wire [31:0] id_rd2 = (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_rs2) ? wb_data : rf_rd2;

  // ---------- the stall (hazard detection) ----------
  // problem: lw gets its number from memory, so the number isnt ready until after the MEM station
  // if the very next instruction needs that number, forwarding cant help yet, so we pause the front of the line for one tick
  // this checks: is the instruction in EX a load, and does the instruction in ID read the register that load is filling
  // (it can pause when it didnt strictly need to, like when an addi constant bits look like a register number, thats safe it just costs one tick)
  wire stall = id_ex_mem_to_reg && (id_ex_rd != 5'd0) && (id_ex_rd == id_rs1 || id_ex_rd == id_rs2);

  // ---------- station 3: EX (execute) ----------
  // forwarding: the number this instruction needs might not be saved in the register file yet because the instruction that makes it is still ahead of us in the line
  // so instead of waiting we grab it straight from the wall where it is sitting
  //   10 = from the EX/MEM wall (the instruction right ahead of us)
  //   01 = from the MEM/WB wall (the one two ahead of us)
  //   00 = no problem, use the number we read in ID
  wire [1:0] fwd_a = (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs1) ? 2'b10 :
                     (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs1) ? 2'b01 : 2'b00;
  wire [1:0] fwd_b = (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs2) ? 2'b10 :
                     (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs2) ? 2'b01 : 2'b00;

  wire [31:0] ex_a = (fwd_a == 2'b10) ? ex_mem_result : (fwd_a == 2'b01) ? wb_data : id_ex_rd1;
  wire [31:0] ex_b = (fwd_b == 2'b10) ? ex_mem_result : (fwd_b == 2'b01) ? wb_data : id_ex_rd2;   // the second register, also the number sw stores

  wire [31:0] alu_b = id_ex_alu_src ? id_ex_imm : ex_b;     // same selector as cpu.v, a register or the constant
  wire [31:0] alu_result;
  wire        zero;

  alu alu_unit(.a(ex_a), .b(alu_b), .op(id_ex_alu_op), .result(alu_result), .zero(zero));

  // branches and jumps get decided here in EX
  wire [31:0] branch_target = id_ex_pc + id_ex_imm;
  wire        take_branch   = (id_ex_branch & zero) | (id_ex_bne & ~zero) | id_ex_jump;
  wire [31:0] ex_result     = id_ex_jump ? (id_ex_pc + 32'd4) : alu_result;   // jal saves pc + 4, everything else saves the alu answer

  // where the pc goes next
  //   a branch or jump was taken: go to the target (the flush below cancels the wrong instructions behind it)
  //   a stall: stay put so the instruction doesnt get lost
  //   otherwise: next instruction
  assign next_pc = take_branch ? branch_target : (stall ? pc : pc_plus4);

  // ---------- station 4: MEM ----------
  wire [31:0] mem_rd;
  data_mem dmem(.clk(clk), .we(ex_mem_mem_write), .addr(ex_mem_result), .wd(ex_mem_store), .rd(mem_rd));

  // ---------- moving everything forward one station every tick ----------
  always @(posedge clk) begin
    if (reset) begin
      // clear every wall so the line starts empty (an all 0 instruction does nothing)
      if_id_pc <= 32'd0;  if_id_instr <= 32'd0;
      id_ex_pc <= 32'd0;  id_ex_rd1 <= 32'd0;  id_ex_rd2 <= 32'd0;  id_ex_imm <= 32'd0;
      id_ex_rs1 <= 5'd0;  id_ex_rs2 <= 5'd0;   id_ex_rd <= 5'd0;
      id_ex_reg_write <= 1'b0;  id_ex_alu_src <= 1'b0;  id_ex_mem_write <= 1'b0;  id_ex_mem_to_reg <= 1'b0;
      id_ex_branch <= 1'b0;     id_ex_bne <= 1'b0;      id_ex_jump <= 1'b0;       id_ex_alu_op <= 4'd0;
      ex_mem_result <= 32'd0;  ex_mem_store <= 32'd0;  ex_mem_rd <= 5'd0;
      ex_mem_reg_write <= 1'b0;  ex_mem_mem_write <= 1'b0;  ex_mem_mem_to_reg <= 1'b0;
      mem_wb_result <= 32'd0;  mem_wb_mem_rd <= 32'd0;  mem_wb_rd <= 5'd0;
      mem_wb_reg_write <= 1'b0;  mem_wb_mem_to_reg <= 1'b0;
    end else begin
      // MEM/WB wall: take what the MEM station produced
      mem_wb_result     <= ex_mem_result;
      mem_wb_mem_rd     <= mem_rd;
      mem_wb_rd         <= ex_mem_rd;
      mem_wb_reg_write  <= ex_mem_reg_write;
      mem_wb_mem_to_reg <= ex_mem_mem_to_reg;

      // EX/MEM wall: take what the EX station produced
      ex_mem_result     <= ex_result;
      ex_mem_store      <= ex_b;
      ex_mem_rd         <= id_ex_rd;
      ex_mem_reg_write  <= id_ex_reg_write;
      ex_mem_mem_write  <= id_ex_mem_write;
      ex_mem_mem_to_reg <= id_ex_mem_to_reg;

      // ID/EX wall: normally take what the ID station produced
      // but if we are stalling or a branch was taken, put a bubble in instead (every switch off, so it does nothing)
      if (stall || take_branch) begin
        id_ex_reg_write <= 1'b0;  id_ex_alu_src <= 1'b0;  id_ex_mem_write <= 1'b0;  id_ex_mem_to_reg <= 1'b0;
        id_ex_branch <= 1'b0;     id_ex_bne <= 1'b0;      id_ex_jump <= 1'b0;       id_ex_alu_op <= 4'd0;
        id_ex_rs1 <= 5'd0;  id_ex_rs2 <= 5'd0;  id_ex_rd <= 5'd0;
      end else begin
        id_ex_reg_write <= c_reg_write;  id_ex_alu_src <= c_alu_src;  id_ex_mem_write <= c_mem_write;
        id_ex_mem_to_reg <= c_mem_to_reg;  id_ex_branch <= c_branch;  id_ex_bne <= c_bne;  id_ex_jump <= c_jump;
        id_ex_alu_op <= c_alu_op;
        id_ex_rs1 <= id_rs1;  id_ex_rs2 <= id_rs2;  id_ex_rd <= id_rd;
      end
      id_ex_pc  <= if_id_pc;
      id_ex_rd1 <= id_rd1;
      id_ex_rd2 <= id_rd2;
      id_ex_imm <= id_imm;

      // IF/ID wall: normally take the newly fetched instruction
      //   branch taken: the instruction we just fetched is the wrong one, so throw it away (all 0 = does nothing), this is the flush
      //   stall: hold the wall as it is so the instruction waits one tick
      if (take_branch) begin
        if_id_instr <= 32'd0;
        if_id_pc    <= 32'd0;
      end else if (!stall) begin
        if_id_instr <= instr;
        if_id_pc    <= pc;
      end
    end
  end

endmodule
