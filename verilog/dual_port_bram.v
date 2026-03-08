module dual_port_bram #(
    parameter DATA_WIDTH = 72,
    parameter ADDR_WIDTH = 8   // 8 bits = 256 entries
)(
    input wire clk,

    // --------------------------------------------------------
    // Port A (Used primarily for Writing: NetFPGA Input or CPU)
    // --------------------------------------------------------
    input wire [ADDR_WIDTH-1:0] addr_a,
    input wire [DATA_WIDTH-1:0] din_a,
    input wire                  we_a,
    output reg [DATA_WIDTH-1:0] dout_a,

    // --------------------------------------------------------
    // Port B (Used primarily for Reading: NetFPGA Output or GPU)
    // --------------------------------------------------------
    input wire [ADDR_WIDTH-1:0] addr_b,
    input wire [DATA_WIDTH-1:0] din_b,
    input wire                  we_b,
    output reg [DATA_WIDTH-1:0] dout_b
);

    // --------------------------------------------------------
    // Memory Array with Xilinx Synthesis Directive
    // --------------------------------------------------------
    // The (* ram_style = "block" *) attribute is critical. 
    // It forces the Xilinx toolchain to map this array to dedicated BRAM.
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] ram_array [(2**ADDR_WIDTH)-1:0];

    // --------------------------------------------------------
    // Port A Synchronous Logic
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (we_a) begin
            ram_array[addr_a] <= din_a;
        end
        // Read-First behavior (outputs the newly written data immediately)
        dout_a <= ram_array[addr_a];
    end

    // --------------------------------------------------------
    // Port B Synchronous Logic
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (we_b) begin
            ram_array[addr_b] <= din_b;
        end
        // Read-First behavior
        dout_b <= ram_array[addr_b];
    end

endmodule
