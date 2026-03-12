module GPU_Data_Memory #(
    parameter DEPTH = 512
)(
    input  wire        clk,
    input  wire        rstb,         // Added reset to detect Host PC mode
    input  wire [7:0]  be,
    input  wire [31:0] addr,
    input  wire [63:0] write_data,
    output reg  [63:0] read_data,

    // Host PC Programming Ports
    input  wire        host_wen,
    input  wire [31:0] host_addr,
    input  wire [31:0] host_wdata
);

    // Force Xilinx to map this array to dedicated Block RAM
    (* ram_style = "block" *) reg [63:0] ram [0:DEPTH-1];

    // =========================================================
    // PORT A: Host PC Bootloader (32-to-64 Bit Packing)
    // =========================================================
    reg [31:0] lower_half_buffer;

    always @(posedge clk) begin
        if (host_wen) begin
            // THE PACKER: Use bit [2] of the address to write the upper or lower half!
            if (host_addr[2] == 1'b0) begin
                // Hold the lower 32 bits (Address + 0) in the staging buffer
                lower_half_buffer <= host_wdata;
            end 
            else begin
                // When the upper 32 bits arrive (Address + 4), write the FULL 64-bit word
                ram[host_addr[11:3]] <= {host_wdata, lower_half_buffer};
            end
        end
    end

    // =========================================================
    // PORT B: GPU & ARM Core (Runtime 64-Bit Operation)
    // =========================================================
    always @(posedge clk) begin
        if (|be) begin
            // Normal 64-bit write operation for the GPU and ARM
            ram[addr[11:3]] <= write_data;
        end
        
        // Synchronous Read: Mapped directly to Port B output
        // (Since the bootloader only writes and never reads, we don't need a read multiplexer here)
        read_data <= ram[addr[11:3]];
    end

endmodule
