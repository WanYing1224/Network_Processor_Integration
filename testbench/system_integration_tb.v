`timescale 1ns/1ps

module system_integration_tb;
    reg clk;
    reg rstb;

    // Simulation Signals
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
        .in_data(in_data),
        .in_wr(in_wr),
        .in_rdy(in_rdy),
        .out_data(out_data),
        .out_wr(out_wr),
        .out_rdy(out_rdy)
    );

    // Clock Gen
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0; rstb = 0;
        in_data = 0; in_wr = 0; out_rdy = 1;

        // Release Reset
        #20 rstb = 1;
        $display("[%0t] System Reset Released. ARM starting execution...", $time);

        // Monitor for GPU Trigger
        // We look inside the hierarchy to see the MUX trigger the GPU
        wait(dut.Arbiter.gpu_run == 1'b1);
        $display("[%0t] ARM triggered GPU! stall_arm_pipeline should be HIGH.", $time);

        // Verify the Stall
        #10;
        if (dut.Arbiter.stall_arm_pipeline) begin
            $display("[%0t] SUCCESS: ARM is successfully stalled. GPU is computing ANN...", $time);
        end

        // Wait for GPU Completion
        wait(dut.Arbiter.gpu_done == 1'b1);
        $display("[%0t] GPU Finished! ARM should resume now.", $time);

        #100;
        $display("[%0t] Simulation Complete. Check Waveforms for BFloat16 results.", $time);
        $finish;
    end
endmodule
