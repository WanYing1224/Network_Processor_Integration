module GPU_Pipeline_Reg #(
    parameter WIDTH = 32
)(
    input wire clk,
    input wire rst,
    input wire stall,
    input wire flush,
    input wire [WIDTH-1:0] d,
	
    output reg [WIDTH-1:0] q
);

    always @(posedge clk or posedge rst) 
    begin
        if (rst) 
        begin
            // Asynchronous Reset: ONLY rst goes here
            q <= {WIDTH{1'b0}};
        end 
        else if (flush) 
        begin
            // Synchronous Flush: Happens on the clock edge
            q <= {WIDTH{1'b0}};
        end
        else if (!stall) 
        begin
            // Normal operation if not stalled
            q <= d;
        end
        // If stalled and not flushed, q implicitly holds its value
    end
	
endmodule
