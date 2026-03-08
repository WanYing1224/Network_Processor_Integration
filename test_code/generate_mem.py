import sys

# Open the binary and the output mem file
with open('test_fifo.bin', 'rb') as f_in, open('..\memory_file\inst_final.mem', 'w') as f_out:
    # Read 4 bytes at a time
    while chunk := f_in.read(4):
        if len(chunk) == 4:
            # Reverse the 4 bytes to fix the little-endian issue!
            reversed_chunk = chunk[::-1]
            f_out.write(reversed_chunk.hex() + '\n')