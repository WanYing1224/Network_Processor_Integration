module convertible_fifo #(
    parameter DATA_WIDTH = 72, // 64-bit data + 8-bit control for NetFPGA
    parameter ADDR_WIDTH = 9   // 512 entries (typical for a small packet buffer)
)(
    input wire clk,
    input wire reset,

    // --------------------------------------------------------
    // Interface 1: NetFPGA Network Stream (Write Port / FIFO Input)
    // --------------------------------------------------------
    input wire [DATA_WIDTH-1:0]  net_data_in,
    input wire                   net_wr_en,
    output wire                  fifo_full,      // Stall signal to NetFPGA

    // --------------------------------------------------------
    // Interface 2: NetFPGA Network Stream (Read Port / FIFO Output)
    // --------------------------------------------------------
    output wire [DATA_WIDTH-1:0] net_data_out,
    input wire                   net_rd_en,
    output wire                  fifo_empty,

    // --------------------------------------------------------
    // Interface 3: Processor Access (ARM CPU / MEM Stage)
    // --------------------------------------------------------
    input wire                   cpu_mode_en,    // 1 = CPU controls memory, 0 = FIFO mode
    input wire [ADDR_WIDTH-1:0]  cpu_addr,       // CPU provides explicit address
    input wire [DATA_WIDTH-1:0]  cpu_data_in,
    input wire                   cpu_wr_en,
    output wire [DATA_WIDTH-1:0] cpu_data_out,

    // --------------------------------------------------------
    // Status / Interrupts
    // --------------------------------------------------------
    output wire                  packet_ready    // Signals processor that a full packet is buffered
);

    // Internal Registers for FIFO management
    reg [ADDR_WIDTH-1:0] head_addr; // Points to the start of the current packet
    reg [ADDR_WIDTH-1:0] tail_addr; // Points to the next write location

    // MUX Logic to select between NetFPGA FIFO mode and Processor mode
    wire [ADDR_WIDTH-1:0] sram_port_a_addr;
    wire [DATA_WIDTH-1:0] sram_port_a_data_in;
    wire                  sram_port_a_we;

    // TODO: Implement Dual-Port Block RAM instantiation
    // TODO: Implement Head/Tail tracking logic and Packet boundary detection
    
endmodule
