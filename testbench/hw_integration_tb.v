`timescale 1ns/1ps

module hw_integration_tb;
    reg clk;
    reg rstb;
    reg  [63:0] in_data;
    reg         in_wr;
    wire        in_rdy;    
    wire [63:0] out_data;  
    wire        out_wr;    
    reg         out_rdy;

    // Instantiate the Full System
    user_datapath dut (
        .clk(clk),
        .rstb(rstb),

        // NetFPGA Input Side
        .in_data(in_data), 
        .in_wr(in_wr), 
        .in_rdy(in_rdy),    

        // NetFPGA Output Side
        .out_data(out_data), 
        .out_wr(out_wr),     
        .out_rdy(out_rdy)
    );
	
	reg [31:0] tb_arm_inst [0:1023];
    reg [31:0] tb_gpu_inst [0:1023];
    reg [63:0] tb_gpu_data [0:511];
    integer i;

    // Clock Gen
    always #5 clk = ~clk;

    initial begin
		
		// Fill arrays with safe zeroes
		for (i = 0; i < 1024; i = i + 1) tb_arm_inst[i] = 32'd0;
        for (i = 0; i < 1024; i = i + 1) tb_gpu_inst[i] = 32'd0;
        for (i = 0; i < 512;  i = i + 1) tb_gpu_data[i] = 64'd0;
		
        // 1. Load the files into the testbench (Synthesizer ignores this!)
        $readmemh("../memory_file/inst_final.mem", tb_arm_inst);
        $readmemh("../memory_file/gpu_program.hex", tb_gpu_inst);
		$readmemh("../memory_file/data_memory.hex", tb_gpu_data);

        // Initialize system
        clk = 0; rstb = 0;
        
        force dut.sw_reset_wire     = 32'd0;
        force dut.sw_mem_addr_wire  = 32'd0;
        force dut.sw_mem_wdata_wire = 32'd0;
        force dut.sw_mem_cmd_wire   = 32'd0;
        
        $display("==== Simulation Starts ====");

        // 🌟 THE FULL PYTHON BOOTLOADER SIMULATION 🌟
        
        // Halt the CPU
        force dut.sw_reset_wire = 32'd1; 
        #20 rstb = 1;
        $display("[%0t] HOST PC: Halting CPU. Flashing full memory arrays...", $time);
        
        // --- Flash ARM IMEM (Route 0x00000000) ---
        for (i = 0; i < 512; i = i + 1) begin
            force dut.sw_mem_addr_wire  = 32'h00000000 + (i * 4);
            force dut.sw_mem_wdata_wire = tb_arm_inst[i];
            force dut.sw_mem_cmd_wire   = 32'd1; 
			
			#10; 
			force dut.sw_mem_cmd_wire = 32'd0; 
			#10;
        end
        $display("[%0t] HOST PC: ARM IMEM Flashed.", $time);

        // --- Flash GPU IMEM (Route 0x20000000) ---
        for (i = 0; i < 1024; i = i + 1) begin
            force dut.sw_mem_addr_wire  = 32'h20000000 + (i * 4);
            force dut.sw_mem_wdata_wire = tb_gpu_inst[i];
            force dut.sw_mem_cmd_wire   = 32'd1; 
			
			#10; 
			force dut.sw_mem_cmd_wire = 32'd0; 
			#10;
        end
        $display("[%0t] HOST PC: GPU IMEM Flashed.", $time);

        // --- Flash GPU DMEM (AI Weights - Route 0x30000000) ---
        for (i = 0; i < 512; i = i + 1) begin
            // 1. Send Lower 32 Bits (Address + 0)
            force dut.sw_mem_addr_wire  = 32'h30000000 + (i * 8);
            force dut.sw_mem_wdata_wire = tb_gpu_data[i][31:0]; 
            force dut.sw_mem_cmd_wire   = 32'd1; 
			
			#10; 
			force dut.sw_mem_cmd_wire = 32'd0; 
			#10;
            
            // 2. Send Upper 32 Bits (Address + 4)
            force dut.sw_mem_addr_wire  = 32'h30000000 + (i * 8) + 4;
            force dut.sw_mem_wdata_wire = tb_gpu_data[i][63:32]; 
            force dut.sw_mem_cmd_wire   = 32'd1; 
			
			#10; 
			force dut.sw_mem_cmd_wire = 32'd0; 
			#10;
        end
        $display("[%0t] HOST PC: GPU DMEM (AI Weights) Flashed.", $time);

        // Release the CPU
        $display("[%0t] HOST PC: Programming complete. Releasing CPU to run the network!", $time);
        force dut.sw_reset_wire = 32'd0; 
        
        // Wait for ARM to Hijack the FIFO
        wait(dut.ARM_Core.fifo_mode_en == 1'b1);
        $display("[%0t] ARM asserted fifo_mode_en! Waiting for network packet...", $time);

        // Simulate Network Packet Arrival using FORCE
        #50;
        $display("[%0t] Injecting Network Packet (Payload: 0x4000400040004000)...", $time);
        
        force dut.ARM_Core.fifo_data_in = 72'h00_4000400040004000;
        
        // THE PRECISION STRIKE: Wait specifically for Thread 0's turn!
        wait(dut.Arbiter.master_addr == 32'h80001004 && dut.ARM_Core.mem_thread_id == 2'b00);
        
        // Force the flag high exactly when Thread 0 is listening
        force dut.ARM_Core.packet_ready = 1'b1;
        @(posedge clk); 
        #1; 
        
        // Drop it immediately so Threads 1, 2, and 3 are blinded and stay trapped
        force dut.ARM_Core.packet_ready = 1'b0;
        
        $display("[%0t] Thread 0 intercepted the packet. Hidden from other threads.", $time);
		
        // Monitor GPU Trigger
        wait(dut.Arbiter.gpu_run == 1'b1);
        $display("[%0t] ARM triggered GPU! stall_arm_pipeline should be HIGH.", $time);

        // Wait for GPU Completion
        wait(dut.Arbiter.gpu_done == 1'b1);
        $display("[%0t] GPU Finished! AI result ready. ARM resuming...", $time);

        // Monitor for ARM writing AI result back to the FIFO payload
        wait(dut.ARM_Core.fifo_wr_en == 1'b1);
        $display("[%0t] ARM is overwriting FIFO Payload at address: 0x%h", $time, dut.ARM_Core.fifo_addr);
        $display("[%0t] ARM Data Out (AI Result): 0x%h", $time, dut.ARM_Core.fifo_data_out);

        // Check if the payload matches our BFloat16 3.5 calculation
        if (dut.ARM_Core.fifo_data_out[31:0] == 32'h40604060) begin
            $display("[%0t] SUCCESS: Network payload successfully modified with AI math!", $time);
        end else begin
            $display("[%0t] ERROR: Unexpected payload data.", $time);
        end

        // Monitor for ARM releasing the FIFO
        wait(dut.ARM_Core.fifo_mode_en == 1'b0);
        $display("[%0t] ARM de-asserted fifo_mode_en. Packet released to network.", $time);

        #100;
        $display("[%0t] Grand Finale Simulation Complete.", $time);
        $finish;
    end
	
endmodule
