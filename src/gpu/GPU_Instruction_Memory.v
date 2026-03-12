module GPU_Instruction_Memory #(
    parameter MEM_DEPTH = 1024 
)(
    input  wire        clk,
    input  wire [31:0] pc,
    output reg  [31:0] instr,
    
    // Host PC Programming Ports
    input  wire        host_wen,
    input  wire [31:0] host_addr,
    input  wire [31:0] host_wdata
);
    
	(* ram_style = "block" *) reg [31:0] ram [0:MEM_DEPTH-1];
/*	
	integer i;
    initial begin
        for(i = 0; i < MEM_DEPTH; i = i + 1) begin
            ram[i] = 32'd0; // Fills memory with 0s instead of Xs
        end
    end
*/
    always @(posedge clk) begin
        if (host_wen) begin
            ram[host_addr[11:2]] <= host_wdata;
        end
		
		instr <= ram[pc[11:2]];
    end
	
endmodule
