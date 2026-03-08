`timescale 1ns/1ps

module gpu_tensor_core_tb;
    reg clk;
    reg rstb;

    // Instantiate the Full System, but ignore the FIFO inputs/outputs
    user_datapath dut (
        .clk(clk),
        .rstb(rstb),
        .in_data(64'd0), .in_wr(1'b0), .in_rdy(),
        .out_data(), .out_wr(), .out_rdy(1'b1)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rstb = 0;
        #20 rstb = 1;
        $display("==== After data_init.hex load ====");
        $display("[%0t] System Reset Released. ARM starting execution...", $time);

        // Monitor GPU Trigger
        wait(dut.Arbiter.gpu_run == 1'b1);
        $display("[%0t] ARM triggered GPU! stall_arm_pipeline should be HIGH.", $time);

        // Verify Stall
        #10;
        if (dut.Arbiter.stall_arm_pipeline == 1'b1)
            $display("[%0t] SUCCESS: ARM is successfully stalled. GPU is computing ANN...", $time);

        // Wait for GPU Completion
        wait(dut.Arbiter.gpu_done == 1'b1);
        $display("[%0t] GPU Finished! ARM should resume now.", $time);

        #100;
        $display("[%0t] Simulation Complete. Check Waveforms for BFloat16 results.", $time);
        $finish;
    end
endmodule
