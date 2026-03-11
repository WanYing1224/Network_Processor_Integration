module GPU_Data_Memory #(
    parameter DEPTH = 512
)(
    input  wire        clk,
    input  wire        rstb,          // Added reset to detect Host PC mode
    input  wire [7:0]  be,
    input  wire [31:0] addr,
    input  wire [63:0] write_data,
    output wire [63:0] read_data,

    // Host PC Programming Ports
    input  wire        host_wen,
    input  wire [31:0] host_addr,
    input  wire [31:0] host_wdata
);
    
	(* ram_style = "block" *) reg [63:0] ram [0:DEPTH-1];
/*	
	integer i;
    initial begin
        for(i = 0; i < DEPTH; i = i + 1) begin
            ram[i] = 64'd0; // Note: This is 64-bit!
        end
    end
*/
    // Multiplexer Logic: If system is in Reset (rstb == 0), Host PC takes over!
    wire        actual_wen   = (host_wen) ? 1'b1 : (|be);
    wire [31:0] actual_addr  = (host_wen) ? host_addr : addr;
    
    // PCIe is 32-bit, BRAM is 64-bit. We pad the top half with zeros.
    wire [63:0] actual_wdata = (host_wen) ? {32'd0, host_wdata} : write_data;

    always @(posedge clk) begin
        if (host_wen) begin
            // 🌟 THE PACKER: Use bit [2] of the address to write the upper or lower half!
            if (host_addr[2] == 1'b0)
                ram[host_addr[11:3]][31:0]  <= host_wdata;
            else
                ram[host_addr[11:3]][63:32] <= host_wdata;
        end 
        else if (|be) begin
            // Normal 64-bit operation for the GPU and ARM
            ram[addr[11:3]] <= write_data;
        end
    end

    // Normal Read

    assign read_data = ram[ (host_wen) ? host_addr[11:3] : addr[11:3] ];

	
endmodule
