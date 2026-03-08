module GPU_Data_Memory #(
    parameter MEM_DEPTH = 1024
)(
    input wire clk,
    input wire [7:0]  be,		  // 8-bit Byte Enable
    input wire [31:0] addr,       // Calculated Base + Offset
    input wire [63:0] write_data, // From Rs_src (ST64)
	
    output wire [63:0] read_data   // To Rd (LD64)
);

    reg [63:0] ram [0:MEM_DEPTH-1];
	
	initial begin
        $readmemh("../memory_file/data_memory.hex", ram);
    end

    assign read_data = ram[addr[11:3]];
	
	integer i;
    always @(posedge clk) begin
        for (i = 0; i < 8; i = i + 1) begin
            if (be[i]) begin
                ram[addr[11:3]][(i*8) +: 8] <= write_data[(i*8) +: 8];
            end
        end
    end
	
endmodule
