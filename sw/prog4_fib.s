# prog4: fibonacci, 15 steps, then stores the last two numbers in memory
_start:
  addi x1, x0, 0          # fib(n)
  addi x2, x0, 1          # fib(n+1)
  addi x3, x0, 15         # steps left
fib:
  beq  x3, x0, fibdone
  add  x4, x1, x2         # next = a + b
  addi x1, x2, 0          # a = b
  addi x2, x4, 0          # b = next
  addi x3, x3, -1
  j    fib
fibdone:
  addi x10, x0, 1
  slli x10, x10, 31
  addi x10, x10, 1024     # x10 = 0x80000400, the data area
  sw   x1, 0(x10)
  sw   x2, 4(x10)
  lw   x5, 0(x10)
  lw   x6, 4(x10)
  sub  x7, x6, x5         # fib(16) - fib(15) = fib(14)
done:
  beq  x0, x0, done       # halt
