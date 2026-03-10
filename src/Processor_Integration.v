`timescale 1ns/1ps

module Processor_Integration #(
    parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = DATA_WIDTH/8,
    parameter UDP_REG_SRC_WIDTH = 2
)(
    // --- NetFPGA Network Stream (Input) ---
    input  [DATA_WIDTH-1:0]             in_data,
    input  [CTRL_WIDTH-1:0]             in_ctrl,
    input                               in_wr,
    output                              in_rdy,

    // --- NetFPGA Network Stream (Output) ---
    output [DATA_WIDTH-1:0]             out_data,
    output [CTRL_WIDTH-1:0]             out_ctrl,
    output                              out_wr,
    input                               out_rdy,
    
    // --- NetFPGA Software Register Interface ---
    input                               reg_req_in,
    input                               reg_ack_in,
    input                               reg_rd_wr_L_in,
    input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
    input  [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,

    output                              reg_req_out,
    output                              reg_ack_out,
    output                              reg_rd_wr_L_out,
    output [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_out,
    output [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_out,
    output [UDP_REG_SRC_WIDTH-1:0]      reg_src_out,

    // --- System Clock & Reset ---
    input                               reset,   // NetFPGA uses Active-HIGH reset
    input                               clk
);

    // ========================================================
    // 1. FIFO / NetFPGA Interface Logic
    // ========================================================
    wire [71:0] net_data_in = {in_ctrl, in_data};
    wire [71:0] net_data_out;
    wire        fifo_full;
    wire        fifo_empty;
    
    // CPU to FIFO Interconnect
    wire        cpu_mode_en;
    wire [7:0]  cpu_addr;      
    wire [71:0] cpu_data_in;
    wire        cpu_wr_en;
    wire [71:0] cpu_data_out;
    wire        packet_ready;

    // Route the FIFO flags to the NetFPGA stream
    assign in_rdy   = ~fifo_full;
    assign out_wr   = ~fifo_empty && !cpu_mode_en; // Only write out if CPU isn't hijacking
    assign out_ctrl = net_data_out[71:64];
    assign out_data = net_data_out[63:0];

    convertible_fifo #(
       .DATA_WIDTH(72),
       .ADDR_WIDTH(8)
    ) u_conv_fifo (
       .clk          (clk),
       .reset        (reset),
       
       // NetFPGA Stream
       .net_data_in  (net_data_in),
       .net_wr_en    (in_wr),
       .fifo_full    (fifo_full),
       .net_data_out (net_data_out),
       .net_rd_en    (out_rdy && ~fifo_empty && !cpu_mode_en), 
       .fifo_empty   (fifo_empty),
       
       // ARM CPU Memory Mapped Ports
       .cpu_mode_en  (cpu_mode_en),
       .cpu_addr     (cpu_addr),
       .cpu_data_in  (cpu_data_out),  // CPU output drives FIFO input
       .cpu_wr_en    (cpu_wr_en),
       .cpu_data_out (cpu_data_in),   // FIFO output drives CPU input
       .packet_ready (packet_ready)
    );

    // ========================================================
    // 2. UDP Registers (Software <-> Hardware Interface)
    // ========================================================
    wire [31:0] reg_reset;
    wire [31:0] reg_mem_addr;
    wire [31:0] reg_mem_wdata;
    wire [31:0] reg_mem_cmd;
    wire [31:0] reg_mem_rdata;
    wire [31:0] reg_pc;
    wire [31:0] reg_instr;

    generic_regs #( 
        .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
        .TAG                 (`CPU_BLOCK_ADDR),     
        .REG_ADDR_WIDTH      (`CPU_REG_ADDR_WIDTH),     
        .NUM_COUNTERS        (0),            
        .NUM_SOFTWARE_REGS   (4), 
        .NUM_HARDWARE_REGS   (3)
    ) module_regs (
        .reg_req_in       (reg_req_in),
        .reg_ack_in       (reg_ack_in),
        .reg_rd_wr_L_in   (reg_rd_wr_L_in),
        .reg_addr_in      (reg_addr_in),
        .reg_data_in      (reg_data_in),
        .reg_src_in       (reg_src_in),

        .reg_req_out      (reg_req_out),
        .reg_ack_out      (reg_ack_out),
        .reg_rd_wr_L_out  (reg_rd_wr_L_out),
        .reg_addr_out     (reg_addr_out),
        .reg_data_out     (reg_data_out),
        .reg_src_out      (reg_src_out),

        // Connect the NetFPGA C/Python script endpoints directly to the ARM
        .software_regs({reg_mem_cmd, reg_mem_wdata, reg_mem_addr, reg_reset}),      
        .hardware_regs({reg_instr, reg_pc, reg_mem_rdata}),            

        .clk              (clk),
        .reset            (reset)
    );

    // ========================================================
    // 3. Multi-Core System-on-Chip (ARM + Arbiter + GPU + BRAM)
    // ========================================================

    // Interconnect Wires
    wire        arm_mem_we;
    wire [31:0] arm_mem_addr;
    wire [31:0] arm_mem_wdata;
    wire [31:0] mux_to_arm_rdata;

    wire        gpu_core_we;
    wire [31:0] gpu_core_addr;
    wire [63:0] gpu_core_wdata;
    wire [63:0] mux_to_gpu_rdata;

    wire [7:0]  mux_to_bram_be;
    wire [31:0] mux_to_bram_addr;
    wire [63:0] mux_to_bram_wdata;
    wire [63:0] bram_to_mux_rdata;

    wire        stall_arm;
    wire        gpu_start;
    wire        gpu_done;

    // ARM Core CPU
    pipelinepc ARM_Core (
        .clk           (clk),
        .rstb          (~reset), // NetFPGA reset is HIGH. ARM expects LOW (rstb).
        
        // Software Control Ports
        .sw_reset      (reg_reset),
        .sw_mem_addr   (reg_mem_addr),
        .sw_mem_wdata  (reg_mem_wdata),
        .sw_mem_cmd    (reg_mem_cmd),
        .hw_mem_rdata  (reg_mem_rdata),
        .hw_pc         (reg_pc),
        .hw_instr      (reg_instr),
        
        // FIFO Interconnect
        .fifo_mode_en  (cpu_mode_en),
        .fifo_addr     (cpu_addr),
        .fifo_data_out (cpu_data_out),
        .fifo_wr_en    (cpu_wr_en),
        .fifo_data_in  (cpu_data_in),
        .packet_ready  (packet_ready),
        
        // GPU Arbiter Interface
        .stall_from_gpu(stall_arm),
        .gpu_mem_we    (arm_mem_we),
        .gpu_mem_addr  (arm_mem_addr),
        .gpu_mem_wdata (arm_mem_wdata),
        .gpu_mem_rdata (mux_to_arm_rdata)
    );

    // Hardware Pulse Generator for GPU Trigger
    reg gpu_start_d;
    always @(posedge clk) begin
        if (reset) gpu_start_d <= 1'b0;
        else       gpu_start_d <= gpu_start; 
    end
    wire gpu_start_pulse = gpu_start & ~gpu_start_d;
	
	// --- Host PC Bootloader Routing Logic for GPU ---
	// NetFPGA reset is Active HIGH, meaning reset==1 when halted
	wire host_write_req   = (reset) && (reg_mem_cmd == 32'd1); 
    wire host_to_gpu_imem = host_write_req && (reg_mem_addr[31:28] == 4'h2);
    wire host_to_gpu_dmem = host_write_req && (reg_mem_addr[31:28] == 4'h3);
	
    // Custom Tensor GPU Core
    gpu_top GPU_Core (
        .clk           (clk),
        .rst           (reset | gpu_start_pulse),
        .host_thread_id(32'd0),
        
        // Memory Interface
        .gpu_mem_we    (gpu_core_we),
        .gpu_mem_addr  (gpu_core_addr),
        .gpu_mem_wdata (gpu_core_wdata),
        .gpu_mem_rdata (mux_to_gpu_rdata),
        
        .gpu_done      (gpu_done), 
		
		.host_wen      (host_to_gpu_imem),
        .host_addr     (reg_mem_addr),
        .host_wdata    (reg_mem_wdata)
    );

    // Multi-core Memory Arbiter
    gpu_mem_mux Arbiter (
        .clk               (clk),
        .rst               (reset),
        
        // ARM Interface
        .arm_we            (arm_mem_we),
        .arm_addr          (arm_mem_addr),
        .arm_wdata         (arm_mem_wdata),
        .arm_rdata         (mux_to_arm_rdata),
        
        // GPU Interface
        .gpu_we            (gpu_core_we),
        .gpu_addr          (gpu_core_addr),
        .gpu_wdata         (gpu_core_wdata),
        .gpu_rdata         (mux_to_gpu_rdata),
        
        // BRAM Master Port
        .master_be         (mux_to_bram_be),
        .master_addr       (mux_to_bram_addr),
        .master_wdata      (mux_to_bram_wdata),
        .master_rdata      (bram_to_mux_rdata),
        
        // Handshake Wires
        .stall_arm_pipeline(stall_arm),
        .gpu_run           (gpu_start),
        .gpu_done          (gpu_done)
    );

    // Shared Dual-Port 64-bit BRAM
    GPU_Data_Memory Shared_Memory (
        .clk       (clk),
		.rstb      (~reset),
        .be        (mux_to_bram_be),
        .addr      (mux_to_bram_addr),
        .write_data(mux_to_bram_wdata),
        .read_data (bram_to_mux_rdata),
		
		.host_wen  (host_to_gpu_dmem),
        .host_addr (reg_mem_addr),
        .host_wdata(reg_mem_wdata)
    );

endmodule
