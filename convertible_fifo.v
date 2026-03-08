module convertible_fifo (
    input clk,
    input reset,
    
    // NetFPGA 接口 (FIFO 模式)
    input [71:0] fifo_in_data,
    input        fifo_in_wr_en,
    output [71:0] fifo_out_data,
    
    // CPU/GPU 接口 (SRAM 模式)
    input [7:0]  cpu_addr_a,      // 256深度需要8位地址
    input [7:0]  cpu_addr_b,
    input [71:0] cpu_data_in,
    input        cpu_wr_en,
    
    // 控制信号
    input        mode_select,    // 0: FIFO Mode, 1: SRAM/Processor Mode
    output reg   fifo_full,
    output reg   data_ready
);

    // 内部寄存器追踪头尾 
    reg [7:0] head_ptr;
    reg [7:0] tail_ptr;

    // 根据模式选择地址输入 [cite: 14, 16]
    wire [7:0] addr_a = mode_select ? cpu_addr_a : tail_ptr;
    wire [7:0] addr_b = mode_select ? cpu_addr_b : head_ptr;

    // 实例化双端口 BRAM [cite: 9, 26, 56]
    // 端口 A 用于写入，端口 B 用于读取
    dual_port_sram_256x72 bram_inst (
        .clk(clk),
        .addr_a(addr_a),
        .din_a(mode_select ? cpu_data_in : fifo_in_data),
        .we_a(mode_select ? cpu_wr_en : fifo_in_wr_en),
        
        .addr_b(addr_b),
        .dout_b(fifo_out_data)
    );

    // FIFO 控制逻辑 
    // 这里需要添加检测“包结束”的逻辑，并更新 tail_ptr 和 head_ptr
    // 当一个完整包存入后，设置 data_ready = 1
    
endmodule