`timescale 1ns/1ps

module fifo_integration_tb;

    // Clock and Reset
    reg clk;
    reg rstb;

    // Software Programming Interface (Holding it inert for this test)
    reg [31:0] sw_reset;
    reg [31:0] sw_mem_addr;
    reg [31:0] sw_mem_wdata;
    reg [31:0] sw_mem_cmd;

    // Hardware Outputs
    wire [31:0] hw_mem_rdata;
    wire [31:0] hw_pc;
    wire [31:0] hw_instr;

    // Convertible FIFO Memory-Mapped Ports
    wire        fifo_mode_en;
    wire [7:0]  fifo_addr;
    wire [71:0] fifo_data_out;
    wire        fifo_wr_en;
    reg  [71:0] fifo_data_in;
    reg         packet_ready;

    // Instantiate the CPU Under Test
    pipelinepc uut (
        .clk(clk),
        .rstb(rstb),
        .sw_reset(sw_reset),
        .sw_mem_addr(sw_mem_addr),
        .sw_mem_wdata(sw_mem_wdata),
        .sw_mem_cmd(sw_mem_cmd),
        .hw_mem_rdata(hw_mem_rdata),
        .hw_pc(hw_pc),
        .hw_instr(hw_instr),
        .fifo_mode_en(fifo_mode_en),
        .fifo_addr(fifo_addr),
        .fifo_data_out(fifo_data_out),
        .fifo_wr_en(fifo_wr_en),
        .fifo_data_in(fifo_data_in),
        .packet_ready(packet_ready)
    );

    // Clock Generation (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // 1. Initialize Testbench Environment
        $display("--- Starting FIFO Integration Test ---");
        clk = 0;
        rstb = 0;
        sw_reset = 32'd0; // Let hardware reset take precedence
        sw_mem_addr = 0;
        sw_mem_wdata = 0;
        sw_mem_cmd = 0;
        
        packet_ready = 1'b0;
        fifo_data_in = 72'h00_1122334455667788; // Dummy payload data

        // 2. Release Reset
        #20;
        rstb = 1;

        // 3. Monitor for CPU taking control
        wait(fifo_mode_en == 1'b1);
        $display("[%0t] CPU asserted fifo_mode_en! (Hijack successful)", $time);

        // 4. Simulate a packet arriving from the network
        #50;
        $display("[%0t] Network Packet Arrived. Asserting packet_ready...", $time);
        packet_ready = 1'b1;

        // 5. Monitor for CPU writing the payload
        wait(fifo_wr_en == 1'b1);
        $display("[%0t] CPU is writing to FIFO Address: 0x%h", $time, fifo_addr);
        $display("[%0t] CPU Data Out: 0x%h", $time, fifo_data_out);
        
        if (fifo_data_out[31:0] == 32'hDEADBEEF) begin
            $display("[%0t] SUCCESS: Payload modification matched expected test pattern!", $time);
        end else begin
            $display("[%0t] ERROR: Unexpected payload data.", $time);
        end

        // 6. Monitor for CPU releasing the FIFO
        wait(fifo_mode_en == 1'b0);
        $display("[%0t] CPU de-asserted fifo_mode_en. Packet released to network.", $time);
        $display("--- Test Complete ---");
        
        #100;
        $finish;
    end

endmodule
