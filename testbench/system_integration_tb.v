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
		
		// Pass the Status Check
		force dut.ARM_Core.packet_ready = 1'b1;
        wait(dut.Arbiter.master_addr == 32'h80001004); // Wait for T0
        @(posedge clk); 
        #1; 
        force dut.ARM_Core.packet_ready = 1'b0; // Drop immediately to trap T1, T2, T3
		
		// Deliver the Payload
		wait(dut.Arbiter.master_addr == 32'h80000000); // Wait for T0 to ask for data
        force dut.ARM_Core.packet_ready = 1'b1; // Turn FIFO output back on!
        @(posedge clk); 
        #1; 
        force dut.ARM_Core.packet_ready = 1'b0; // Drop it permanently
        
        $display("[%0t] Thread 0 safely intercepted the packet and data!", $time);

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
        if (dut.ARM_Core.fifo_data_out[31:0] == 32'h40C040C0) begin
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
