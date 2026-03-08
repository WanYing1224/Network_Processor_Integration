.text
    .global _start
_start:
    @ 1. Hijack the Network FIFO
    MOV R0, #0x80
    LSL R0, R0, #24
    ADD R0, R0, #0x1000
    MOV R1, #1
    STR R1, [R0]

    @ 2. Polling Loop
    ADD R2, R0, #0x04
wait_loop:
    LDR R3, [R2]         @ Read Status Register
    CMP R3, #1           @ Is a packet ready?
    BEQ process_packet   @ If YES, jump out of the loop!
    B wait_loop          @ If NO, keep waiting.

process_packet:
    @ 3. Read the Network Packet Payload
    MOV R4, #0x80
    LSL R4, R4, #24      
    LDR R5, [R4]         

    @ 4. Feed Payload to GPU
    MOV R7, #0x81
    LSL R7, R7, #24      
    STR R5, [R7]         

    @ 5. Trigger GPU
    ADD R8, R7, #0x1000
    MOV R10, #1
    STR R10, [R8]        

    @ 6. Read Result & Overwrite Network Payload
    LDR R11, [R7]        
    STR R11, [R4]

    @ 7. Release FIFO
    MOV R1, #0
    STR R1, [R0]

end_loop:
    B end_loop