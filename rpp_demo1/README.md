# RealProbe Demo 1

This folder is set up from the RealProbe matrix-multiplication tutorial example:

https://realprobe-doc.readthedocs.io/en/latest/tutorial/ex1.html

What was customized for this machine:

- `Makefile` points at the repo-local `../realprobe` checkout.
- `Makefile` uses Linux Vitis HLS 2023.1 from `/home/htran304/tools/Xilinx/Vitis_HLS/2023.1/bin/vitis_hls`.
- `Makefile` defaults `HLS_BUILD_PATH` to `/home/htran304/tools/Xilinx/Vitis_HLS/2023.1/lnx64/tools/clang-3.9-csynth`.
- `Makefile` uses Linux Vivado 2023.1 from `/home/htran304/tools/Xilinx/Vivado/2023.1/bin/vivado`.
- `Makefile` exports the locale and `LD_LIBRARY_PATH` settings needed by the Linux Xilinx tools in this environment.
- `Makefile` defaults `RUN_COSIM=0` on Linux because Vitis HLS 2023.1 co-simulation is not stable in this WSL setup.
- The shared `realprobe/` scripts were patched so reruns are clean and the generated Vivado flow emits the RapidWright-style DCP outputs.

Run from WSL/Linux in this directory:

```bash
make realprobe
```

If you want to try the Linux co-simulation step anyway:

```bash
make realprobe RUN_COSIM=1
```

If your Xilinx install lives somewhere else, you can override the defaults:

```bash
make realprobe XILINX_ROOT=/path/to/Xilinx
```

Optional baseline flow:

```bash
make base
```

Expected outputs after a successful run:

- `project/`
- `vivado/`
- `FPGA/design_1.bit`
- `FPGA/design_1.hwh`
- `FPGA/fpga.ipynb`

Notes:

- The tutorial requires the Tcl file name to stay `hls.tcl`.
- The variable names `solution_name`, `project_name`, and `target_device` in `hls.tcl` must remain unchanged.
- A successful `make realprobe` will also copy these DCPs into `vivado/` for the RapidWright reference inserter:
- `vivado/design_1_wrapper_routed.dcp`
- `vivado/design_1_realprobe_ip_0_0.dcp`
- `vivado/design_1_axi_bram_ctrl_0_0.dcp`
