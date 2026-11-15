# prog2: two loops
# loop 1 adds 10 + 9 + ... + 1 using bne to go back to the top (answer 55 in x2)
# loop 2 multiplies 9 x 13 by adding 13 nine times (answer 117 in x5)
.globl _start
_start:
  addi x1, x0, 10         # counter
  addi x2, x0, 0          # sum
sumloop:
  add  x2, x2, x1         # sum = sum + counter
  addi x1, x1, -1         # counter = counter - 1
  bne  x1, x0, sumloop    # keep going until the counter is 0

  addi x3, x0, 9          # how many times to add
  addi x4, x0, 13         # the number to add
  addi x5, x0, 0          # the answer
mulloop:
  beq  x3, x0, muldone    # stop when the count reaches 0
  add  x5, x5, x4
  addi x3, x3, -1
  j    mulloop            # jump back to the top (jal with no link register)
muldone:
  slt  x6, x2, x5         # 55 < 117 so 1
done:
  beq  x0, x0, done       # halt
