module fifo_control #(
    parameter ADDR_WIDTH = 9
)(
    input wire                  clk,
    input wire                  reset,
    
    // NetFPGA Interface
    input wire                  net_wr_en,
    input wire [7:0]            net_ctrl_in,
    
    // Processor Interface
    input wire                  cpu_mode_en,   // 1 = CPU active, 0 = NetFPGA active
    
    // Control Outputs
    output reg [ADDR_WIDTH-1:0] head_addr,
    output reg [ADDR_WIDTH-1:0] tail_addr,
    output reg                  fifo_full,
    output reg                  packet_ready
);

    reg packet_is_buffering;

    always @(posedge clk) begin
        if (reset) begin
            head_addr           <= {ADDR_WIDTH{1'b0}};
            tail_addr           <= {ADDR_WIDTH{1'b0}};
            packet_is_buffering <= 1'b0;
            packet_ready        <= 1'b0;
            fifo_full           <= 1'b0;
        end else begin
            // MODE 0: FIFO Network Receiving Mode
            if (!cpu_mode_en) begin
                
                // Reset flags if the processor has finished processing
                if (!packet_ready && fifo_full) begin
                    fifo_full <= 1'b0;
                end

                // Write incoming data and track boundaries
                if (net_wr_en && !fifo_full) begin
                    tail_addr <= tail_addr + 1'b1;
                    
                    // Detect Start of Packet (SOP)
                    if (!packet_is_buffering) begin
                        packet_is_buffering <= 1'b1;
                        head_addr <= tail_addr; // Lock head address to packet start
                    end

                    // Detect End of Packet (EOP)
                    if (packet_is_buffering && (net_ctrl_in != 8'h00)) begin
                        packet_ready        <= 1'b1; // Signal processor
                        fifo_full           <= 1'b1; // Stall next incoming packet
                        packet_is_buffering <= 1'b0;
                    end
                end
				
				// Drain logic: Increment head when NetFPGA requests data
                if (net_rd_en && (head_addr != tail_addr)) begin
                    head_addr <= head_addr + 1'b1;
                end
                
                // Reset full flag once the buffer is successfully drained
                if (!packet_ready && fifo_full && (head_addr == tail_addr)) begin
                    fifo_full <= 1'b0;
                end
				
            end
            
            // MODE 1: Processor Intervention Mode
            else if (cpu_mode_en) begin
                // Pointers hold steady while the processor accesses memory.
                // Logic to clear `packet_ready` via a CPU write can be added here later.
            end
        end
    end
endmodule
