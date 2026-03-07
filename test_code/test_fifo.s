.text
    .global _start
_start:
    @ =====================================================
    @ PART 1: FIFO HIJACK (Existing Logic)
    @ =====================================================
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
    ADD R2, R2, #0x04

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

    @ =====================================================
    @ PART 2: GPU CO-PROCESSOR TEST (New Sequence)
    @ =====================================================
    
    @ 6. Construct 0x81000000 in R7 (GPU Memory Base)
    @ This address targets the shared 64-bit BRAM via gpu_mem_mux
    MOV R7, #0x81
    LSL R7, R7, #24

    @ 7. Construct a test vector (e.g., 0xCAFEBABE) in R9
    @ In a real ANN, this would be your BFloat16 weights
    MOV R9, #0xCA
    LSL R9, R9, #8
    ADD R9, R9, #0xFE
    LSL R9, R9, #8
    ADD R9, R9, #0xBA
    LSL R9, R9, #8
    ADD R9, R9, #0xBE

    @ Write the vector to the 64-bit BRAM
    @ Note: gpu_mem_mux will handle the 32-to-64 bit padding!
    STR R9, [R7]

    @ 8. Construct 0x81001000 in R8 (GPU Control Register)
    ADD R8, R7, #0x1000

    @ 9. TRIGGER THE CO-PROCESSOR
    @ Writing a '1' here pulses 'gpu_run' to the gpu_top.v
    @ 🌟 CRITICAL: The hardware (gpu_mem_mux) will automatically
    @ assert 'stall_from_gpu' now. The ARM core will FREEZE here
    @ and will not execute the next instruction until the GPU is DONE.
    MOV R10, #1
    STR R10, [R8]

    @ 10. Read back the result from GPU Memory
    @ This instruction only executes AFTER the GPU completes its math
    @ and releases the ARM pipeline stall.
    LDR R11, [R7]

end_loop:
    B end_loop
	