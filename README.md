# Network Processor Integration

## Project Overview
This repository contains the source code, test scripts, and documentation for EE533 Lab 8. The objective is to design and integrate a specialized Convertible FIFO, an ARM-compatible CPU, and a custom GPU into the NetFPGA pipeline. 

## Directory Structure
* `/src` - Verilog source files for the FIFO, CPU, and GPU integration.
* `/sim` - ModelSim simulation outputs and testbenches.
* `/test_code` - Assembly codes for processor testing and tensor operations for the GPU.
* `/docs` - Daily commit logs, synthesis reports, and the final lab report.

## Hardware Components
1. **Convertible FIFO**: Designed with Block RAM instantiated as dual-port SRAM to buffer network packets and stall incoming data via a FIFO FULL signal.
2. **ARM ISA CPU**: Interfaced to modify packet payloads and route them back to the destination IP.
3. **Custom GPU**: Augmented with multiplexers for direct memory access to perform pipelined Bfloat16 tensor operations.

## Daily Commit Log
*(Maintain a record of your daily commits and their detailed descriptions here as required by the lab instructions.)*
