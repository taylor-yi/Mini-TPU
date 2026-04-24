# Mini TPU: 4×4 BF16 Systolic Array

## Project Overview
This repository contains the SystemVerilog implementation and verification environment for a 4×4 systolic array matrix multiply accelerator. Inspired by modern ML accelerators, this design utilizes BF16 (Brain Float 16) arithmetic in each processing element (PE) for compact datapaths, while accumulating in FP32 internally to preserve numerical precision across the 4-MAC reduction.

## Architecture Highlights
* **BF16 Arithmetic:** Custom IEEE-style BF16 floating-point arithmetic (multiply and add) implemented from scratch.
* **Processing Element (PE):** Computes a fused multiply-accumulate (MAC), multiplying two BF16 inputs and adding the product to an FP32 accumulator.
* **Systolic Dataflow:** Weight-stationary architecture where weights are pre-loaded into each PE and held, while input activations are staggered by one cycle per row.

## Repository Structure
* **`bf16_*.sv`**: Core arithmetic modules including utilities, multiplier, adder, and the PE wrapper.
* **`systolic_array.sv` & `mini_tpu_top.sv`**: The 4×4 array instantiation and top-level integration.
* **`controller.sv` & `mem_interface.sv`**: FSM for compute/drain phases and data buffering.
* **`golden_model.py`**: Reference BF16 matrix multiplication in Python (using numpy and struct) for test vector generation.
* **`tb_*.sv`**: Testbenches for unit testing and end-to-end verification.

## Tools & Environment
* **Simulation:** ModelSim (SystemVerilog support required)
* **Waveform Viewer:** GTKWave or Verdi
* **Verification:** Python 3 (numpy, struct) for the golden model

## Team & Responsibilities
* **Tyler Braham:** Python golden model, tbd.
* **Taylor Yi:** tbd.