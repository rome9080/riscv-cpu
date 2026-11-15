# turns a raw program file (bytes) into the hex format our instruction memory loads
# one 32 bit instruction per line, 8 hex digits, the first instruction on the first line
import sys

data = open(sys.argv[1], "rb").read()
data += b"\x00" * (-len(data) % 4)          # pad to a whole number of 4 byte words
with open(sys.argv[2], "w") as out:
    for i in range(0, len(data), 4):
        word = int.from_bytes(data[i:i + 4], "little")   # risc-v stores the lowest byte first
        out.write("%08X\n" % word)
