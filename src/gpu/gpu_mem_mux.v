module gpu_mem_mux(
    input wire clk,
    input wire rst,

    // ==========================================
    // Master Output (Connects to gpu_data_memory.v)
    // ==========================================
	output wire [7:0] master_be,         // 8-bit Byte Enables
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

    wire is_host_access = (arm_addr[31:24] == 8'h81);
    wire is_gpu_control_reg = is_host_access && (arm_addr == 32'h8100_1000);
    wire is_gpu_sram_access = is_host_access && !is_gpu_control_reg;
	
    reg precedence; // 1 = Host Master, 0 = GPU Master

    // Arbitration Logic: Seize memory control and hold CPU
    always @(posedge clk) begin
        if (rst) begin
            stall_arm_pipeline <= 1'b0;
            gpu_run            <= 1'b0;
			precedence         <= 1'b1;
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

    // Address Multiplexing
    assign master_addr  = precedence ? arm_addr : gpu_addr;
	
	//Data Write Multiplexing
    assign master_wdata = precedence ? {arm_wdata, arm_wdata} : gpu_wdata;

	// Byte Enable Logic
    wire [7:0] arm_formatted_be = arm_addr[2] ? 8'hF0 : 8'h0F;
	assign master_be = precedence ? ((is_gpu_sram_access && arm_we) ? arm_formatted_be : 8'h00) : (gpu_we ? 8'hFF : 8'h00);

    // Connect raw 64-bit path back to the pure GPU core
    assign gpu_rdata = master_rdata;

    // Data Read Translation 
    assign arm_rdata = arm_addr[2] ? master_rdata[63:32] : master_rdata[31:0];
    assign gpu_rdata = master_rdata;

endmodule
