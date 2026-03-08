`timescale 1ns/1ps

module system_integration_tb;
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

    // Clock Gen
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0; rstb = 0;
		$display("==== Simulation Starts ====");

        // Release Reset
        #20 rstb = 1;
        $display("[%0t] System Reset Released. ARM starting execution...", $time);

        // Wait for ARM to Hijack the FIFO
        wait(dut.ARM_Core.fifo_mode_en == 1'b1);
        $display("[%0t] ARM asserted fifo_mode_en! Waiting for network packet...", $time);

        // Simulate Network Packet Arrival using FORCE
        #50;
        $display("[%0t] Injecting Network Packet (Payload: 0x4000400040004000)...", $time);
        
        force dut.ARM_Core.fifo_data_in = 72'h00_4000400040004000;
        
        // 🌟 THE PRECISION STRIKE: Wait specifically for Thread 0's turn!
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
