`timescale 1ns/1ps

module pc_wrapper
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2
   )
   (
      input  [DATA_WIDTH-1:0]             in_data,
      input  [CTRL_WIDTH-1:0]             in_ctrl,
      input                               in_wr,
      output                              in_rdy,

      output [DATA_WIDTH-1:0]             out_data,
      output [CTRL_WIDTH-1:0]             out_ctrl,
      output                              out_wr,
      input                               out_rdy,
      
      input                               reg_req_in,
      input                               reg_ack_in,
      input                               reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]      reg_src_in,

      output                              reg_req_out,
      output                              reg_ack_out,
      output                              reg_rd_wr_L_out,
      output [`UDP_REG_ADDR_WIDTH-1:0]    reg_addr_out,
      output [`CPCI_NF2_DATA_WIDTH-1:0]   reg_data_out,
      output [UDP_REG_SRC_WIDTH-1:0]      reg_src_out,

      input                               reset,
      input                               clk
   );

   assign out_data = in_data;
   assign out_ctrl = in_ctrl;
   assign out_wr   = in_wr;
   assign in_rdy   = out_rdy;

   wire [31:0] reg_reset;
   wire [31:0] reg_mem_addr;
   wire [31:0] reg_mem_wdata;
   wire [31:0] reg_mem_cmd;
   
   wire [31:0] reg_mem_rdata;
   wire [31:0] reg_pc;
   wire [31:0] reg_instr;

   generic_regs
   #( 
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`CPU_BLOCK_ADDR),     
      .REG_ADDR_WIDTH      (`CPU_REG_ADDR_WIDTH),     
      .NUM_COUNTERS        (0),            
      .NUM_SOFTWARE_REGS   (4), 
      .NUM_HARDWARE_REGS   (3)
   ) module_regs (
      .reg_req_in       (reg_req_in),
      .reg_ack_in       (reg_ack_in),
      .reg_rd_wr_L_in   (reg_rd_wr_L_in),
      .reg_addr_in       (reg_addr_in),
      .reg_data_in       (reg_data_in),
      .reg_src_in        (reg_src_in),

      .reg_req_out      (reg_req_out),
      .reg_ack_out      (reg_ack_out),
      .reg_rd_wr_L_out  (reg_rd_wr_L_out),
      .reg_addr_out     (reg_addr_out),
      .reg_data_out     (reg_data_out),
      .reg_src_out      (reg_src_out),

      .software_regs({reg_mem_cmd, reg_mem_wdata, reg_mem_addr, reg_reset}),      
      
      .hardware_regs({reg_instr, reg_pc, reg_mem_rdata}),            

      .clk              (clk),
      .reset            (reset)
    );

   pipelinepc my_cpu (
        .clk           (clk),
        .rstb          (~reset), 
        
        .sw_reset      (reg_reset),
        .sw_mem_addr   (reg_mem_addr),
        .sw_mem_wdata  (reg_mem_wdata),
        .sw_mem_cmd    (reg_mem_cmd),
        
        .hw_mem_rdata  (reg_mem_rdata),
        .hw_pc         (reg_pc),
        .hw_instr      (reg_instr)
   );

endmodule