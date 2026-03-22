# RealProbe Demo 1

This folder is set up from the RealProbe matrix-multiplication tutorial example:

https://realprobe-doc.readthedocs.io/en/latest/tutorial/ex1.html

What was customized for this machine:

- `Makefile` points at the local `RealProbe` checkout.
- `Makefile` defaults `HLS_BUILD_PATH` to the Windows-native Vitis HLS frontend at `C:/Xilinx/Vitis_HLS/2023.2/win64/tools/clang-3.9-csynth`.
- `Makefile` uses Git Bash so the Unix-style recipe commands work on Windows.
- `Makefile` calls the installed Xilinx 2023.2 binaries directly.
- The shared `RealProbe/realprobe` checkout was patched so it resolves `max_depth.txt` from `REALPROBE_PATH`.

Run from PowerShell in this directory:

```powershell
make realprobe
```

If you have a custom Windows RealProbe LLVM/HLS build, you can override the default:

```powershell
make realprobe HLS_BUILD_PATH=C:/path/to/your/hls-build
```

Optional baseline flow:

```powershell
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
- The checked-in `RealProbe/llvm-project/hls-build` in this workspace is a Linux build, so this demo does not use it by default with the Windows Vitis flow.
