# RealProbe🔍
**In-FPGA profiling tool for HLS designs**


## About

RealProbe is a fully-automated profiling tool to extract on-FPGA performance. 
With just one line---#pragma HLS RealProbe---our tool automatically generates all the code necessary to profile the exact cycle counts of an entire function hierarchy on-board. 
It is developed and maintained by [Jiho Kim][1] from [Sharc Lab][2] at [Georgia Tech][3].

[1]: https://jihoray.github.io/
[2]: https://sharclab.ece.gatech.edu/
[3]: https://www.gatech.edu/



## Useful Links

- Paper: [FCCM 2025][11]
- Docs: [RealProbe][9]
- Tutorial: [FCCM 2024 Tutorial & ESWEEK 2024 Tutorial][10]

[9]: https://realprobe-doc.readthedocs.io/en/latest
[10]: https://sharclab.ece.gatech.edu/open-source-projects/
[11]: https://arxiv.org/html/2504.03879v1


## Requirements

RealProbe expects AMD/Xilinx Vitis HLS (a part of the [Vitis Unified Software Platform][4]) and [Vivado][5] to be present on the machine it is running on. This includes setting up the environment, as described in the [Vitis HLS documentation][6], and setting up the environment, as described in the [Vivado documentation][7].

For FPGA board, we expect the board to support [PYNQ framework](https://pynq.readthedocs.io/en/latest/). 

Other than that, RealProbe is fully integrated into Vitis HLS and Vivado toolchain, requiring no additional environment settings or tool installations. 

All testing has been performed using Vitis HLS 2023.1 and Vivado 2023.1, though we expect any version with an [HLS LLVM frontend][8] release.

[4]: https://www.xilinx.com/products/design-tools/vitis/vitis-platform.html
[5]: https://www.xilinx.com/products/design-tools/vivado.html
[6]: https://docs.xilinx.com/r/en-US/ug1399-vitis-hls/Setting-Up-the-Environment?tocId=5N~0A2HNuVzvrGYgw0ja_A
[7]: https://docs.amd.com/r/en-US/ug910-vivado-getting-started/Installing-the-Vivado-Design-Suite
[8]: https://github.com/Xilinx/hls-llvm-project

## Validated Setup

This repository has been validated with a Linux-only flow using:

- Vitis HLS 2023.1 for HLS and RealProbe generation
- Vivado 2023.1 for block design, implementation, bitstream generation, and DCP export
- target device `xc7z020clg400-1`

If you are installing Vivado 2023.1, make sure the install includes the Zynq-7000 device family. The demo flow will fail at project creation if that device support is missing.

## Quick Start

1. Install Linux Vitis HLS 2023.1 and Linux Vivado 2023.1.
2. Confirm these binaries exist, or adjust paths later:

```bash
/path/to/Xilinx/Vitis_HLS/2023.1/bin/vitis_hls
/path/to/Xilinx/Vivado/2023.1/bin/vivado
```

3. Clone this repository:

```bash
git clone <your-repo-url> realprobe_plus
cd realprobe_plus
```

4. Run the validated demo flow:

```bash
cd rpp_demo1
make realprobe
```

5. After a successful run, the demo produces:

- `FPGA/design_1.bit`
- `FPGA/design_1.hwh`
- `FPGA/fpga.ipynb`
- `vivado/design_1_wrapper_routed.dcp`
- `vivado/design_1_realprobe_ip_0_0.dcp`
- `vivado/design_1_axi_bram_ctrl_0_0.dcp`

See `rpp_demo1/README.md` for the full demo-specific setup notes.


## Usage

```bash
git clone https://github.com/sharc-lab/RealProbe.git
cd RealProbe
```


> **Warning**
>
> The Tcl file name must remain `hls.tcl`, and the variable names inside it such as `project_name`, `solution_name`, and `target_device` must not be changed.

For a new project, copy the shared Makefile into your HLS project directory and point it at your Linux Xilinx install:

```bash
cp /path/to/realprobe_plus/realprobe/Makefile .
```

The main variables to set or override are:

```bash
XILINX_ROOT=/path/to/Xilinx
REALPROBE_PATH=/path/to/realprobe_plus/realprobe
HLS_BUILD_PATH=/path/to/Xilinx/Vitis_HLS/2023.1/lnx64/tools/clang-3.9-csynth
VITIS_HLS=/path/to/Xilinx/Vitis_HLS/2023.1/bin/vitis_hls
VIVADO=/path/to/Xilinx/Vivado/2023.1/bin/vivado
```

Then run:

```bash
make realprobe
```

Optional:

- `make base` runs the baseline HLS-to-Vivado flow without the RealProbe instrumentation path.
- `make realprobe RUN_COSIM=1` enables HLS co-simulation. This repository has now been validated with `RUN_COSIM=1` on Linux Vitis HLS 2023.1 using `XSIM`, but it requires the `zip` utility to be installed on the system.
- `FPGA/fpga.ipynb` is auto-generated from the HLS register map plus RealProbe recorder metadata. It loads `design_1.bit`, talks to the kernel IP and `axi_bram_ctrl_0`, and includes cells to dump and plot recorder timing data on the board.
- `make function <name>` now reuses the same notebook generator as the full flow. It filters to the selected function's `ap_start` recorders and keeps the matching recorder depths when that function exposes probeable `ap_start` signals.
- `rapidwright_realprobe_inserter/` contains a parameterized RapidWright checkpoint inserter for cases where you want to inject RealProbe into existing DCPs instead of rerunning the normal RealProbe HLS flow. Its wrapper now defaults to a 2-stage RapidWright-plus-Vivado path that emits a normal final DCP.

<!---
All available command-line options can be viewed by running `realprobe --help`.
<div>
  <p align="center"> **On-FPGA profiling tool for HLS designs** </p>
</div>
-->
