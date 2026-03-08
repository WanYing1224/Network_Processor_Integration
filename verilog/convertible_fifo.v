module convertible_fifo #(
    parameter DATA_WIDTH = 72, 
    parameter ADDR_WIDTH = 8   // 8 bits = 256 depth
)(
    input wire clk,
    input wire reset,

    // --------------------------------------------------------
    // NetFPGA Interface (Write Port / Input)
    // --------------------------------------------------------
    input wire [DATA_WIDTH-1:0]  net_data_in,
    input wire                   net_wr_en,
    output wire                  fifo_full,

    // --------------------------------------------------------
    // NetFPGA Interface (Read Port / Output)
    // --------------------------------------------------------
    output wire [DATA_WIDTH-1:0] net_data_out,
    input wire                   net_rd_en,
    output wire                  fifo_empty, 

    // --------------------------------------------------------
    // Processor Interface (ARM CPU)
    // --------------------------------------------------------
    input wire                   cpu_mode_en,
    input wire [ADDR_WIDTH-1:0]  cpu_addr,
    input wire [DATA_WIDTH-1:0]  cpu_data_in,
    input wire                   cpu_wr_en,
    output wire [DATA_WIDTH-1:0] cpu_data_out,

    // --------------------------------------------------------
    // Status Flags
    // --------------------------------------------------------
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
    // 2. Multiplexer Logic for Port A (NetFPGA Write / CPU Access)
    // --------------------------------------------------------
    // CPU takes over address and data lines when cpu_mode_en is HIGH.
    wire [ADDR_WIDTH-1:0] sram_porta_addr = cpu_mode_en ? cpu_addr    : tail_addr;
    wire [DATA_WIDTH-1:0] sram_porta_data = cpu_mode_en ? cpu_data_in : net_data_in;
    wire                  sram_porta_we   = cpu_mode_en ? cpu_wr_en   : net_wr_en;

    // --------------------------------------------------------
    // 3. Multiplexer Logic for Port B (NetFPGA Read)
    // --------------------------------------------------------
    // NetFPGA reads from the head of the FIFO. 
    // No writing occurs on Port B in this phase of the lab.
    wire [ADDR_WIDTH-1:0] sram_portb_addr = head_addr; 
    wire [DATA_WIDTH-1:0] sram_portb_data = {DATA_WIDTH{1'b0}}; 
    wire                  sram_portb_we   = 1'b0; 

    // --------------------------------------------------------
    // 4. Dual-Port BRAM Instantiation
    // --------------------------------------------------------
    dual_port_bram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_dual_port_bram (
        .clk(clk),
        
        // Port A connections
        .addr_a(sram_porta_addr),
        .din_a(sram_porta_data),
        .we_a(sram_porta_we),
        .dout_a(cpu_data_out),     // CPU reads out from Port A

        // Port B connections
        .addr_b(sram_portb_addr),
        .din_b(sram_portb_data),
        .we_b(sram_portb_we),
        .dout_b(net_data_out)      // NetFPGA pipeline reads out from Port B
    );

    // --------------------------------------------------------
    // 5. Basic Empty Flag
    // --------------------------------------------------------
    assign fifo_empty = (head_addr == tail_addr);

endmodule
