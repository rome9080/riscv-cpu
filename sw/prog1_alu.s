# prog1: tries every alu instruction we have, with positive numbers, negative numbers, and shifts
# the comments say what each answer should be (as plain numbers)
_start:
  addi x1, x0, 100        # x1 = 100
  addi x2, x0, -7         # x2 = -7
  add  x3, x1, x2         # 93
  sub  x4, x1, x2         # 107
  and  x5, x1, x2         # bitwise and of 100 and -7
  or   x6, x1, x2         # bitwise or
  xor  x7, x1, x2         # bitwise xor
  addi x8, x0, 3          # shift amount
  sll  x9, x1, x8         # 100 shifted left by 3 = 800
  srl  x10, x2, x8        # -7 shifted right by 3, a logical shift so the top fills with 0s
  slt  x11, x2, x1        # -7 < 100 so 1
  slt  x12, x1, x2        # 100 < -7 is false so 0
  andi x13, x1, 0x3c      # and with a constant
  ori  x14, x1, 0x0f      # or with a constant
  xori x15, x1, -1        # xor with all ones flips every bit
  slti x16, x2, 0         # -7 < 0 so 1
  slli x17, x1, 4         # 100 shifted left by 4 = 1600
  srli x18, x2, 28        # -7 shifted right by 28
  addi x19, x0, 2047      # biggest constant addi can hold
  addi x20, x0, -2048     # smallest constant addi can hold
  add  x21, x19, x20      # -1
  sub  x22, x20, x19      # -4095
  slt  x23, x20, x19      # -2048 < 2047 so 1
done:
  beq  x0, x0, done       # halt: jumps to itself forever
