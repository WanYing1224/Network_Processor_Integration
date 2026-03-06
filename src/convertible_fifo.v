module convertible_fifo #(
    parameter DATA_WIDTH = 72, 
    parameter ADDR_WIDTH = 9   
)(
    input wire clk,
    input wire reset,

    // NetFPGA Interface (Input)
    input wire [DATA_WIDTH-1:0]  net_data_in,
    input wire                   net_wr_en,
    output wire                  fifo_full,

    // NetFPGA Interface (Output)
    output wire [DATA_WIDTH-1:0] net_data_out,
    input wire                   net_rd_en,
    output wire                  fifo_empty,

    // Processor Interface
    input wire                   cpu_mode_en,
    input wire [ADDR_WIDTH-1:0]  cpu_addr,
    input wire [DATA_WIDTH-1:0]  cpu_data_in,
    input wire                   cpu_wr_en,
    output wire [DATA_WIDTH-1:0] cpu_data_out,

    // Status
    output wire                  packet_ready
);

    // Internal wires connecting to the control module
    wire [ADDR_WIDTH-1:0] head_addr;
    wire [ADDR_WIDTH-1:0] tail_addr;
    wire [7:0]            net_ctrl_in = net_data_in[71:64];

    // --------------------------------------------------------
    // 1. Instantiate Control Logic
    // --------------------------------------------------------
    fifo_control #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fifo_ctrl (
        .clk(clk),
        .reset(reset),
        .net_wr_en(net_wr_en),
        .net_ctrl_in(net_ctrl_in),
        .cpu_mode_en(cpu_mode_en),
        .head_addr(head_addr),
        .tail_addr(tail_addr),
        .fifo_full(fifo_full),
        .packet_ready(packet_ready)
    );

    // --------------------------------------------------------
    // 2. Multiplexer Logic for SRAM Port A (Write Port)
    // --------------------------------------------------------
    // When cpu_mode_en is 1, CPU controls the address and data.
    // When 0, the NetFPGA network stream controls them.
    wire [ADDR_WIDTH-1:0] sram_porta_addr = cpu_mode_en ? cpu_addr    : tail_addr;
    wire [DATA_WIDTH-1:0] sram_porta_data = cpu_mode_en ? cpu_data_in : net_data_in;
    wire                  sram_porta_we   = cpu_mode_en ? cpu_wr_en   : net_wr_en;

    // --------------------------------------------------------
    // 3. Dual-Port Block RAM Instantiation (Placeholder)
    // --------------------------------------------------------
    // Port A is used for Write (NetFPGA input or CPU write)
    // Port B is used for Read (NetFPGA output or CPU read)
    
    // TODO: Instantiate the actual Dual-Port SRAM module here using sram_porta_* // and standard Port B read logic based on head_addr.

endmodule
