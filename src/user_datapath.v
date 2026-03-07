module user_datapath #(
    parameter DATA_WIDTH = 64
)(
    input  wire clk,
    input  wire rstb,

    // Interface to NetFPGA Stream (8 Gbps Network Input)
    input  wire [DATA_WIDTH-1:0] in_data,
    input  wire                  in_wr,
    output wire                  in_rdy,

    // Interface to NetFPGA Output (8 Gbps Network Output)
    output wire [DATA_WIDTH-1:0] out_data,
    output wire                  out_wr,
    input  wire                  out_rdy
);

    // Block: The Top Left MUX
    // ARM <-> MUX Interconnect
    wire        arm_mem_we;
    wire [31:0] arm_mem_addr;
    wire [31:0] arm_mem_wdata;
    wire [31:0] mux_to_arm_rdata;

    // GPU Core <-> MUX Interconnect
    wire        gpu_core_we;
    wire [31:0] gpu_core_addr;
    wire [63:0] gpu_core_wdata;
    wire [63:0] mux_to_gpu_rdata;

    // MUX <-> Shared BRAM Interconnect
    wire [7:0]  mux_to_bram_we;
    wire [31:0] mux_to_bram_addr;
    wire [63:0] mux_to_bram_wdata;
    wire [63:0] bram_to_mux_rdata;

    // Co-Processor Control
    wire        stall_arm;
    wire        gpu_start;
    wire        gpu_done;

    // Block: ARM ISA CPU
    pipelinepc ARM_Core (
        .clk(clk),
        .rstb(rstb),
        .stall_from_gpu(stall_arm), // NEW: Freezes ARM while GPU runs
        
        // Memory-Mapped Ports to GPU Arbiter
        .gpu_mem_we(arm_mem_we),
        .gpu_mem_addr(arm_mem_addr),
        .gpu_mem_wdata(arm_mem_wdata),
        .gpu_mem_rdata(mux_to_arm_rdata)
        
        // ... (other existing ports like hw_instr, etc.)
    );

    // Block: GPU (Simple CPU + Tensor Core)
    gpu_top GPU_Core (
        .clk(clk),
        .rst(rstb | gpu_start), // Pulse starts the GPU execution
        .host_thread_id(32'd0),
        
        // Memory Interface
        .gpu_mem_we(gpu_core_we),
        .gpu_mem_addr(gpu_core_addr),
        .gpu_mem_wdata(gpu_core_wdata),
        .gpu_mem_rdata(mux_to_gpu_rdata),
        
        .gpu_done(gpu_done)
    );

    // Block: The Top Left MUX
    gpu_mem_mux Arbiter (
        .clk(clk),
        .rst(!rstb),
        
        // ARM Interface
        .arm_we(arm_mem_we),
        .arm_addr(arm_mem_addr),
        .arm_wdata(arm_mem_wdata),
        .arm_rdata(mux_to_arm_rdata),
        
        // GPU Interface
        .gpu_we(gpu_core_we),
        .gpu_addr(gpu_core_addr),
        .gpu_wdata(gpu_core_wdata),
        .gpu_rdata(mux_to_gpu_rdata),
        
        // BRAM Master Port
        .master_we(mux_to_bram_we),
        .master_addr(mux_to_bram_addr),
        .master_wdata(mux_to_bram_wdata),
        .master_rdata(bram_to_mux_rdata),
        
        .stall_arm_pipeline(stall_arm),
        .gpu_run(gpu_start),
        .gpu_done(gpu_done)
    );

    // Block: Shared BRAM
    GPU_Data_Memory Shared_Memory (
        .clk(clk),
        .we(mux_to_bram_we),
        .addr(mux_to_bram_addr),
        .write_data(mux_to_bram_wdata),
        .read_data(bram_to_mux_rdata)
    );

endmodule
