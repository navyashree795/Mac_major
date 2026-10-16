# High-Performance Multiply-Accumulate (MAC) Unit: Base Paper Specifications, Modern Improvements, and RTL-to-GDSII Flow

---

## 1. Executive Summary & Project Context

* **Project Title:** Design, Architectural Improvement, and ASIC Implementation of a High-Performance Low-Power Pipelined MAC Unit using an Open-Source RTL-to-GDSII Flow.
* **Target Domain:** Digital Signal Processing (DSP), Edge Artificial Intelligence (AI/ML) Acceleration, and Matrix Multiplier Systolic Arrays.
* **Flow & Toolchain:** 100% Open-Source ASIC Implementation (Verilog RTL -> Yosys -> OpenROAD / OpenLane -> Magic / KLayout / Netgen -> GDSII).
* **Reference Base Paper:** 
  * *Title:* "A High-Performance Multiply-Accumulate Unit by Integrating Additions and Accumulations Into Partial Product Reduction Process"
  * *Authors:* Che-Wei Tung and Shih-Hsu Huang (Senior Member, IEEE)
  * *Publication:* IEEE Access, Vol. 8, May 2020 (DOI: 10.1109/ACCESS.2020.2992286).

---

## 2. Base Paper Architecture & Complete Specifications

### 2.1 Core Architectural Innovation
In conventional MAC designs, multiplications and accumulations are evaluated sequentially with separate adders, leading to two long carry-propagation paths:
1. Carry propagation during final addition in the multiplier.
2. Carry propagation during addition in the accumulator.

The base paper resolves this by:
* Integrating the addition and accumulation of higher-significance bits directly into the **Partial Product Reduction (PPR)** matrix of the *subsequent* multiplication cycle.
* Truncating the multiplier's final adder so that only lower bits are resolved in Stage 1, while higher bits are saved in carry-save form in registers.
* Handling matrix overflow carries via a dedicated small-size carry counter accumulator.
* Employing power gating for Stage 2 so that final vector accumulation only computes during the terminal cycle of a multi-cycle dot product.

---

### 2.2 System Parameters & Bit-Widths

| Parameter | Symbol | Paper Base Spec | Toy Example Spec | Description |
| :--- | :---: | :---: | :---: | :--- |
| **Input Operand Width** | N | **16 bits** | 4 bits | Inputs `Input_X[N-1:0]` and `Input_Y[N-1:0]` |
| **Guard Bits** | α (alpha) | **8 bits** | 2 bits | Accommodates up to 2^α = 256 consecutive MAC operations without overflow |
| **Deferred Bit Count** | k | **13 to 17 bits** (recommended: **k = 16 ≈ N**) | 3 bits | Higher-significance bits deferred to the next cycle's PPR matrix |
| **Accumulator Output Width** | 2N + α - 1 | **39 bits** (full dynamic range: 40 bits) | 9 bits | Final accumulated result `REG_Result` |
| **Pipeline Latency** | — | **2 clock cycles** | 2 cycles | Stage 1 (PPG + PPR + Partial Adder + Overflow) -> Stage 2 (Final Adder) |
| **Throughput** | — | **1 MAC / cycle** | 1 MAC / cycle | Pipelined execution rate |
| **Number Format** | — | **Unsigned & Signed** | Both | Signed numbers use 2's complement representation |

---

### 2.3 Stage Breakdown and Register Organization

#### Stage 1: PPG, PPR, and Partial Final Addition
* **Input Registers:**
  * `REG_X`: N bits (16 bits)
  * `REG_Y`: N bits (16 bits)
* **Partial Product Generation (PPG):**
  * *Unsigned Mode:* Array of N × N AND gates.
  * *Signed Mode:* Modified Baugh-Wooley algorithm; inserts an extra constant '1' at column (N+1).
* **Reduction Tree (PPR):**
  * Uses the **Dadda tree** approach (selected over Wallace tree because Dadda uses fewer Half Adders and Full Adders for asymmetric matrices).
* **Accumulation Storage (`register accumulation`):**
  * `REG1` (Row 1): **2N - 1 bits** (31 bits for N=16)
  * `REG2` (Row 2): **k bits** (16 bits for k=16)
  * `REG3` (Row 3): **1 bit**
* **Stage 1 Partial Final Adder:**
  * Adder width: **(2N - k - 1) bits** (for N=16, k=16: **15-bit adder** instead of a full 31-bit adder).
  * Computes the sum of the lowest (2N - k - 1) bits from the Dadda reduction rows.
* **Overflow / Carry Counter Adder:**
  * Accumulates overflow bits `car[0]` and `car[1]` that exceed column (2N - 1).
  * `REG4`: **α bits** (8 bits for α=8).

#### Stage 2: Final Vector Addition & Gating
* **Stage 2 Final Adder:**
  * Adder width: **(k + α) bits** (for N=16, k=16, α=8: **24-bit adder** instead of a conventional 39-bit adder).
  * Lower (2N - k - 1) bits are routed directly from `REG1` without any adder logic.
* **Clock/Operand Gating:**
  * The (k + α)-bit adder is enabled only on the **final cycle** of the dot-product sequence via an `enable` signal, eliminating dynamic switching power during intermediate cycles.

---

### 2.4 Overflow Translation Mechanisms

#### Unsigned Mode Translation:
```text
Translation_Output = car[0] + car[1]
```
* `car[1:0] = 2'b00` -> `2'b00` (Decimal 0)
* `car[1:0] = 2'b01` or `2'b10` -> `2'b01` (Decimal 1)
* `car[1:0] = 2'b11` -> `2'b10` (Decimal 2)
* *Hardware Implementation:* 1 XOR gate (Sum) and 1 AND gate (Carry).

#### Signed (2's Complement) Mode Translation:
In Baugh-Wooley arithmetic, the omitted MSB column weight corresponds to -2^(2N-1). To compensate, the carry value subtracts 1:
```text
Translation_Output = car[0] + car[1] - 1
```
* `car[1:0] = 2'b00` -> `2'b11` (Decimal -1 in 2-bit 2's complement)
* `car[1:0] = 2'b01` or `2'b10` -> `2'b00` (Decimal 0)
* `car[1:0] = 2'b11` -> `2'b01` (Decimal +1)

---

### 2.5 Base Paper Benchmark Results (TSMC 40nm Standard Cell Library)

Synthesized using Synopsys Design Compiler under a **1.0 ns timing constraint (1.0 GHz frequency)**:

#### Unsigned 16-bit MAC (N=16, α=8, Delay <= 1.0 ns):
| Model | Area (µm²) | Delay (ns) | Power (mW) | Energy (pJ) | Energy Saving vs Conventional |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Conventional (DT + Ripple Carry)** | 2943.64 | 0.98 | 1.3247 | 1.30 | Baseline (100%) |
| **Conventional (DT + Carry Lookahead)** | 3050.46 | 0.98 | 1.3589 | 1.33 | +2.58% |
| **State-of-the-Art (Hoang et al.)** | 2430.61 | 0.98 | 1.3065 | 1.28 | -1.37% |
| **Proposed Ours_17 (k=17)** | 1970.21 | 0.98 | 0.8438 | 0.83 | **-36.30%** |
| **Proposed Ours_16 (k=16)** | **1961.81** | **0.97** | **0.8440** | **0.82** | **-36.94%** |
| **Proposed Ours_15 (k=15)** | 1949.57 | 0.97 | 0.8839 | 0.86 | -33.96% |

#### Signed 16-bit MAC (N=16, α=8, Delay <= 1.0 ns):
| Model | Area (µm²) | Delay (ns) | Power (mW) | Energy (pJ) | Energy Saving vs Conventional |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Conventional (DT + Ripple Carry)** | 2804.38 | 0.98 | 1.3349 | 1.31 | Baseline (100%) |
| **State-of-the-Art (Hoang et al.)** | 2417.46 | 0.97 | 1.3451 | 1.30 | -0.26% |
| **Proposed Ours_16 (k=16)** | **1996.66** | **0.97** | **0.8410** | **0.82** | **-37.64%** |

#### Systolic Array Benchmarks (at 1.0 GHz):
* **3 × 3 Systolic Array (Ours):** Area = 17,969.94 µm², Power = 25.44 mW (28.8% area reduction, 29.4% power reduction vs conventional).
* **5 × 5 Systolic Array (Ours):** Area = 49,916.50 µm², Power = 114.35 mW (28.8% area reduction, 31.5% power reduction vs conventional).

---

## 3. Bottlenecks in the Base Architecture & Improvement Opportunities

1. **Throughput Bottleneck:**
   * *Limitation:* Fixed at 1 multiply-accumulate per cycle.
   * *Opportunity:* Introduce subword parallelism (SIMD) to achieve **2× or 4× throughput** when executing low-precision operations.
2. **Partial Product Row Count:**
   * *Limitation:* Generates N rows (16 rows for 16-bit), creating a tall reduction tree.
   * *Opportunity:* Apply **Radix-4 Modified Booth Encoding (MBE)** to cut partial product rows from 16 down to 8.
3. **PPR Routing Congestion in Physical ASIC Design:**
   * *Limitation:* Dadda trees have irregular inter-column interconnects, creating wire congestion during automated place-and-route.
   * *Opportunity:* Implement modular **4:2 and 5:2 compressor slices** to ensure regular layout channels and lower parasitic capacitance.
4. **Stage 2 Carry Propagation:**
   * *Limitation:* Standard adders can become the critical path at sub-nanosecond clock periods.
   * *Opportunity:* Implement a parallel prefix adder (**Han-Carlson** or **Brent-Kung**) for the (k + α)-bit final addition.
5. **Precision Inflexibility:**
   * *Limitation:* Locked to 16-bit integers.
   * *Opportunity:* Make the datapath reconfigurable (1× 16-bit, 2× 8-bit, or 4× 4-bit) for Deep Learning inference workloads.

---

## 4. Modern Improvements from Recent Literature (2021–2026)

### 4.1 Radix-4 / Radix-8 Modified Booth Encoding (MBE)
* **Concept:** Groups adjacent bits of the multiplier operand to produce scaled partial products from {-2, -1, 0, +1, +2}.
* **Benefits:** 
  * Reduces 16 partial product rows to 8 rows (50% reduction).
  * Combined with feedback accumulation, the reduction matrix height drops from 19 rows to only 11 rows.
  * Significantly reduces switching activity, dynamic power, and gate count.

### 4.2 Structured 4:2 and 5:2 Compressor Trees
* **Concept:** Replaces irregular Full/Half Adder networks with balanced 4:2 compressor modules.
* **Benefits:**
  * Compresses 4 inputs + 1 carry-in into 1 sum + 1 carry-out with a constant delay of 3 XOR gates.
  * Symmetrical bit-slice structure dramatically improves placement and routing in OpenLane / OpenROAD, mitigating setup time violations.

### 4.3 Subword Parallel Reconfigurable MAC (Double / Quad Throughput)
* **Concept:** Partitioning the 16-bit reduction tree using mode-control logic (e.g., STAR / PSMAC architectures, 2023–2025):
  * **16-bit Mode:** 1 MAC / cycle (high-precision audio, radar, scientific computing).
  * **Dual 8-bit Mode (2× Throughput):** Two independent 8-bit MAC operations per cycle (INT8 deep learning inference).
  * **Quad 4-bit Mode (4× Throughput):** Four parallel 4-bit MAC operations per cycle (quantized edge AI models).
* **Benefits:** Achieves up to 400% higher compute density for AI workloads with less than 15% hardware area overhead.

### 4.4 Approximate / Truncated Computing for Edge AI
* **Concept:** Truncating or simplifying the lowest 6 to 8 columns in the PPR matrix using approximate OR-compressors.
* **Benefits:** 25% to 45% power and area savings with less than 0.5% inference accuracy degradation in CNN / Transformer tasks.

---

## 5. State of the Art: Bit-Widths in Modern MAC Units

```
[ Sub-Byte AI / LLMs ]          [ Mainstream Mixed-Precision ]       [ High-Dynamic-Range DSP ]
  FP4 / NVFP4 / MXFP4                FP8 (E4M3, E5M2)                     INT16 / INT32
      INT4                                 BF16 / FP16                         FP32 / FP64
(NVIDIA Blackwell, NPUs)              (Hopper, Gaudi, TPU)                (Radar, Audio, HPC)
```

### 5.1 Ultra-Low Precision (The 2024–2026 Frontier)
* **FP4 (NVFP4 / OCP MXFP4):**
  * Formalized in the **Open Compute Project (OCP) Microscaling Formats (MX)** specification (2023–2025) and deployed in the **NVIDIA Blackwell B200 / GB200 architecture (2024)**.
  * 4-bit floating point multiplication accumulated into 16-bit or 32-bit registers.
* **INT4 (4-bit Integer):**
  * Predominant in mobile NPUs (Qualcomm Hexagon, Apple Neural Engine, Google Tensor TPU) for on-device quantized LLM inference (e.g., LLaMA-4bit).

### 5.2 Mainstream AI Workloads (2022–2025)
* **FP8 (8-bit Floating Point):**
  * **E4M3:** 1 sign, 4 exponent, 3 mantissa bits (optimal for weights and activations).
  * **E5M2:** 1 sign, 5 exponent, 2 mantissa bits (optimal for gradients and backpropagation).
  * Supported in NVIDIA Hopper H100, AMD MI300X, Intel Gaudi 3, and Google TPU v5p/v6.
* **INT8 (8-bit Integer):**
  * Standard format for convolutional neural networks, computer vision, and edge DSPs.
* **BF16 / FP16:**
  * 16-bit floating point multiplication accumulated into FP32 registers.

### 5.3 Traditional DSP, Telecom, and Scientific Computing
* **16-bit Fixed Point (Base Paper Reference):**
  * Standard for telecom, software-defined radio (SDR), audio processing (e.g., TI TMS320, ARM Cortex-M55/M85 Helium).
  * Configured as 16-bit × 16-bit + 40-bit accumulation (with 8 guard bits).
* **32-bit (Q31 Fixed-Point & FP32):**
  * High-precision radar, medical ultrasound, and robotics control loops.
* **64-bit (FP64 / Double Precision):**
  * High-Performance Computing (HPC), quantum simulations, and scientific modelling.

---

## 6. Proposed Major Project Implementation Plan (Open-Source RTL-to-GDSII)

### 6.1 Recommended Project Architecture
* **Baseline Module:** Parameterized Base MAC (N=16, α=8, k=16) with deferred PPR accumulation and carry counter.
* **Proposed Enhancement (Option A - High Value):** Reconfigurable Multi-Precision MAC (1× 16-bit or 2× 8-bit Double-Throughput).
* **Proposed Enhancement (Option B - Frequency & Area):** Radix-4 Booth + Symmetrical 4:2 Compressor Tree + Han-Carlson Final Adder.

### 6.2 Toolchain & Flow Setup
* **RTL Design & Simulation:**
  * Verilog-2001 / SystemVerilog parameterized code.
  * Simulation: Icarus Verilog (`iverilog`) + GTKWave / Verilator.
  * Automated self-checking testbench verifying against 100,000 randomized test vectors (including overflow edge cases).
* **Synthesis & Logic Optimization:**
  * Tool: **Yosys**.
  * Checks: Cell count, gate-level timing paths, area utilization.
* **Physical Implementation (PnR to GDSII):**
  * Flow: **OpenLane / OpenROAD**.
  * Steps: Floorplanning -> Power Grid Generation (PDN) -> Placement -> Clock Tree Synthesis (CTS) -> Global & Detailed Routing -> Antenna / DRC Fixes.
* **Signoff & DRC/LVS:**
  * DRC / GDSII Generation: **Magic** & **KLayout**.
  * LVS Verification: **Netgen**.
  * Static Timing Analysis (STA): **OpenSTA**.
* **Target Open-Source PDK:**
  * **SkyWater 130nm (`sky130_fd_sc_hd`)** or **Nangate 45nm / FreePDK45**.
