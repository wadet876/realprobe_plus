# RealProbe Demo 1

This folder is set up from the RealProbe matrix-multiplication tutorial example:

https://realprobe-doc.readthedocs.io/en/latest/tutorial/ex1.html

## Prerequisites

The validated flow for this demo is Linux-only:

- Linux Vitis HLS 2023.1
- Linux Vivado 2023.1
- Vivado installed with Zynq-7000 device support for `xc7z020clg400-1`

The default paths in this repo assume:

- Vitis HLS at `/home/htran304/tools/Xilinx/Vitis_HLS/2023.1`
- Vivado at `/home/htran304/tools/Xilinx/Vivado/2023.1`

If your install lives somewhere else, override `XILINX_ROOT` when you run `make`.

## Repo-Specific Changes

What was customized in this repo:

- `Makefile` points at the repo-local `../realprobe` checkout.
- `Makefile` uses Linux Vitis HLS 2023.1 from `/home/htran304/tools/Xilinx/Vitis_HLS/2023.1/bin/vitis_hls`.
- `Makefile` defaults `HLS_BUILD_PATH` to `/home/htran304/tools/Xilinx/Vitis_HLS/2023.1/lnx64/tools/clang-3.9-csynth`.
- `Makefile` uses Linux Vivado 2023.1 from `/home/htran304/tools/Xilinx/Vivado/2023.1/bin/vivado`.
- `Makefile` exports the locale and `LD_LIBRARY_PATH` settings needed by the Linux Xilinx tools in this environment.
- `Makefile` defaults `RUN_COSIM=0` on Linux because Vitis HLS 2023.1 co-simulation is not stable in this WSL setup.
- The shared `realprobe/` scripts were patched so reruns are clean and the generated Vivado flow emits the RapidWright-style DCP outputs.

## Setup

1. Open a Linux shell or WSL shell.
2. Change into this directory:

```bash
cd /path/to/realprobe_plus/rpp_demo1
```

3. If needed, override the Xilinx install root:

```bash
make realprobe XILINX_ROOT=/path/to/Xilinx
```

4. Otherwise, run the validated default flow:

```bash
make realprobe
```

## Optional Commands

Try HLS co-simulation too:

```bash
make realprobe RUN_COSIM=1
```

If you enable `RUN_COSIM=1`, make sure the `zip` utility is installed and available on `PATH`.

Run the baseline non-RealProbe flow:

```bash
make base
```

## Expected Outputs

After a successful `make realprobe`, this folder will contain:

- `project/`
- `vivado/`
- `FPGA/design_1.bit`
- `FPGA/design_1.hwh`
- `FPGA/fpga.ipynb`

It will also copy the RapidWright-style DCPs into `vivado/`:

- `vivado/design_1_wrapper_routed.dcp`
- `vivado/design_1_realprobe_ip_0_0.dcp`
- `vivado/design_1_axi_bram_ctrl_0_0.dcp`

## Notebook Usage

`FPGA/fpga.ipynb` is generated automatically from the HLS control-register header and the RealProbe recorder metadata.

The notebook is set up to:

- load `design_1.bit` with PYNQ
- talk to the kernel as `ol.matrixmul_0`
- read RealProbe timing data through `ol.axi_bram_ctrl_0`
- dump per-recorder start/end timestamps
- plot a simple execution timeline

If you run `make function <name>`, the notebook generator now follows that retargeted selection too. It keeps only the selected function's `ap_start` recorders and maps the matching tripcounts into the notebook. If the selected `_under.txt` file has no `ap_start` signals, the retargeted notebook cannot be generated for that selection.

## Notes

- The tutorial requires the Tcl file name to stay `hls.tcl`.
- The variable names `solution_name`, `project_name`, and `target_device` in `hls.tcl` must remain unchanged.
- The Makefile handles the locale and `LD_LIBRARY_PATH` setup needed by the Linux Xilinx tools in this environment.
- `RUN_COSIM=1` has been validated with `XSIM` in this setup.
- The Vivado run still emits some warnings from generated Xilinx IP and PS7 constraints, but the validated flow completes successfully through routed DCP and bitstream generation.
