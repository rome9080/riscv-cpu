# prog3: loads and stores
# the spike side puts memory at 0x80000000, so x10 is set to 0x80000400 and used as the base for all the data
# (the cpu only looks at the bottom bits of the address so it behaves the same)
.globl _start
_start:
  addi x10, x0, 1
  slli x10, x10, 31       # x10 = 0x80000000
  addi x10, x10, 1024     # x10 = 0x80000400, the data area
  addi x1, x0, 11
  addi x2, x0, -3
  sw   x1, 0(x10)         # store 11
  sw   x2, 4(x10)         # store -3
  lw   x3, 0(x10)         # load 11 back
  lw   x4, 4(x10)         # load -3 back
  add  x5, x3, x4         # 8, uses the numbers right after they were loaded
  sw   x5, 8(x10)
  lw   x6, 8(x10)

  addi x7, x0, 0          # i = 0
  addi x8, x0, 5          # count = 5
  addi x11, x10, 16       # pointer to the start of an array
fill:
  beq  x7, x8, filled
  addi x13, x7, 100       # the value to store is i + 100
  sw   x13, 0(x11)
  addi x11, x11, 4        # next slot
  addi x7, x7, 1
  j    fill
filled:
  addi x11, x10, 16       # go back to the start of the array
  addi x7, x0, 0
  addi x14, x0, 0         # sum
sumloop:
  beq  x7, x8, summed
  lw   x13, 0(x11)
  add  x14, x14, x13      # adds the number right after loading it
  addi x11, x11, 4
  addi x7, x7, 1
  j    sumloop
summed:
  sw   x14, 40(x10)       # 100 + 101 + 102 + 103 + 104 = 510
  lw   x15, 40(x10)
done:
  beq  x0, x0, done       # halt
