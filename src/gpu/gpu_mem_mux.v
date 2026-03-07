module gpu_mem_mux(
    input wire clk,
    input wire rst,

    // ==========================================
    // Master Output (Connects to gpu_data_memory.v)
    // ==========================================
    output wire        master_we,
	output wire [63:0] master_be,        // 64-bit Byte Enables
    output wire [31:0] master_addr,      // Memory Address
    output wire [63:0] master_wdata,     // Write Data
    input  wire [63:0] master_rdata,     // Read Data

    // ==========================================
    // GPU Port (Connects to gpu_top.v ports)
    // ==========================================
    input  wire        gpu_we,          // GPU Write Enable
    input  wire [31:0] gpu_addr,        // GPU Address
    input  wire [63:0] gpu_wdata,       // GPU Write Data
    output wire [63:0] gpu_rdata,       // GPU Read Data

    // ==========================================
    // ARM Host Port (Connects to pipelinepc.v)
    // ==========================================
    input  wire        arm_we,          // ARM Write Enable
    input  wire [31:0] arm_addr,        // ARM Address
    input  wire [31:0] arm_wdata,       // ARM Write Data (32-bit!)
    output wire [31:0] arm_rdata,       // ARM Read Data (32-bit!)

    // ==========================================
    // Co-processor Control Interface
    // ==========================================
    output reg         stall_arm_pipeline, // Hold CPU in WAIT state
    output reg         gpu_run,             // Pulse high to start gpu_top execution
    input  wire        gpu_done             // Gpu_top asserts when finished
);

    // -----------------------------------------------------------------
    // 1. Host Memory-Mapped I/O Decoding (Address Range: 0x81xxxxxx)
    // -----------------------------------------------------------------
    wire is_host_access = (arm_addr[31:24] == 8'h81);
    
    // Define a control register at 0x8100_1000 for triggering the co-processor
    wire is_gpu_control_reg = is_host_access && (arm_addr == 32'h8100_1000);
    
    // The main 64-bit data memory array starts at 0x8100_0000
    wire is_gpu_sram_access = is_host_access && !is_gpu_control_reg;

    // -----------------------------------------------------------------
    // 2. State Machine: Host Arbitration and Stalling
    // -----------------------------------------------------------------
    reg precedence; // 1 = Host Master, 0 = GPU Master

    // Arbitration Logic: Seize memory control and hold CPU
    always @(posedge clk) begin
        if (rst) begin
            stall_arm_pipeline <= 1'b0;
            gpu_run            <= 1'b0;
        end else begin
            // Clear pulses
            gpu_run <= 1'b0;

            // Scenario 1: ARM wants to write ANN parameters to 64-bit memory.
            if (is_gpu_sram_access) begin
                precedence <= 1'b1; // Grab master control immediately.
            end

            // Scenario 2: ARM wants to TRIGGER GPU execution
            else if (is_gpu_control_reg && arm_we && arm_wdata[0]) begin
                precedence         <= 1'b0; // Relinquish memory control to the co-processor
                stall_arm_pipeline <= 1'b1; // Stall the ARM so it doesn't cause a data hazard!
                gpu_run            <= 1'b1; // Pulse 'Start' to gpu_top.v
            end
            
            // Scenario 3: Wait for co-processor done signal
            else if (stall_arm_pipeline && gpu_done) begin
                stall_arm_pipeline <= 1'b0; // Release the ARM to read the results
                precedence         <= 1'b1; // Grab master control back
            end
        end
    end

    // -----------------------------------------------------------------
    // 3. 64-bit Master Signal Multiplexing
    // -----------------------------------------------------------------
    // Mux selects active master based on state (1 = Host, 0 = GPU)
    assign master_we    = precedence ? (is_gpu_sram_access && arm_we) : gpu_we;
    assign master_addr  = precedence ? arm_addr : gpu_addr;
    assign master_wdata = precedence ? {32'h0, arm_wdata} : gpu_wdata; // Zero-pad ARM writes

    // -----------------------------------------------------------------
    // 4. Data Translation: 32-bit Host reads 64-bit Master RDATA
    // -----------------------------------------------------------------
    // We must handle the mismatch. ARM reads either the lower 32-bits or the 
    // upper 32-bits of the 64-bit word depending on the address LSB.
    // Address Even = [31:0], Address Odd = [63:32]
    assign arm_rdata = arm_addr[0] ? master_rdata[63:32] : master_rdata[31:0];

    // Connect raw 64-bit path back to the pure GPU core
    assign gpu_rdata = master_rdata;

    // -----------------------------------------------------------------
    // 5. Byte-Enable Translation (Critical for ARM writes)
    // -----------------------------------------------------------------
    // The ARM writes 32 bits into a 64-bit bus. We must use Byte Enables (BE)
    // so we don't clobber the other half of the 64-bit BFloat16/SIMD word.
    // Assuming Data_Memory.v supports standard byte masking...
    wire [63:0] arm_formatted_be = arm_addr[0] ? 64'hF0F0_F0F0_0000_0000 : 64'h0000_0000_F0F0_F0F0;
    wire [63:0] gpu_full_be      = {64{1'b1}}; // GPU writes all 64 bits.

    assign master_be = precedence ? arm_formatted_be : gpu_full_be;

endmodule
