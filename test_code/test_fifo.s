.text
    .global _start
_start:
    @ 1. Construct 0x80001000 in R0
    MOV R0, #0x80
    NOP
    NOP
    NOP
    LSL R0, R0, #24
    NOP
    NOP
    NOP
    ADD R0, R0, #0x1000
    MOV R1, #1
    NOP
    NOP
    NOP
    STR R1, [R0]

    @ 2. Polling Loop Setup
    ADD R2, R0, #0x04
    NOP
    NOP
    NOP
wait_loop:
    LDR R3, [R2]
    NOP
    NOP
    NOP
    CMP R3, #1
    NOP
    NOP
    NOP
    BEQ process_packet
    NOP
    NOP
    NOP
    B wait_loop

process_packet:
    MOV R4, #0x80
    MOV R7, #0x81
    NOP
    NOP
    NOP
    LSL R4, R4, #24
    LSL R7, R7, #24
    NOP
    NOP
    NOP
    LDR R5, [R4]     @ Read Payload
    NOP
    NOP
    NOP
    STR R5, [R7]     @ Write Payload to GPU
    
    @ Trigger GPU
    ADD R8, R7, #0x1000
    MOV R10, #1
    NOP
    NOP
    NOP
    STR R10, [R8]

    @ Read Result and Overwrite Payload
    LDR R11, [R7]
    NOP
    NOP
    NOP
    STR R11, [R4]

    @ Release FIFO
    MOV R1, #0
    NOP
    NOP
    NOP
    STR R1, [R0]

end_loop:
    B end_loop
	