# RapidWright RealProbe Inserter

This directory contains a parameterized RapidWright-based checkpoint inserter for `realprobe_plus`.

Unlike the standard `make realprobe` flow, this path starts from existing DCPs and injects the RealProbe IP and AXI BRAM controller into a routed design checkpoint.

## What It Does

The inserter:

- reads an original routed design checkpoint
- reads synthesized DCPs for the RealProbe IP and AXI BRAM controller
- copies those netlist cells into the target design
- instantiates them under a selected block design instance
- connects the RealProbe read-data bus to the BRAM controller read-data bus
- optionally reconstructs a small LUT-based probe source and connects it to a RealProbe input
- writes a new output checkpoint

The helper wrapper now defaults to a 2-stage flow:

- generate or refresh a readable top-level EDIF bundle for the original DCP when needed
- run the RapidWright insertion into an intermediate `*_rapidwright.dcp`
- source the generated `*_rapidwright_load.tcl` in Vivado
- write a final Vivado-native output DCP

This keeps the encrypted-IP handling internal to the script. The final requested `output_dcp` is intended to open in Vivado with plain `open_checkpoint`.

## Requirements

- Java
- RapidWright, available either through:
  - `RAPIDWRIGHT_PATH` pointing to a RapidWright checkout/build, or
  - `RAPIDWRIGHT_JAR` pointing to a RapidWright jar

The helper script expects a RapidWright layout that exposes classes from `bin` and jars from `jars/`, which matches a normal RapidWright checkout.

For this repository, the validated combination is:

- Java 17
- RapidWright `v2023.1.4-beta`
- Vivado 2023.1-era DCPs

## Files

- [`RealProbeInserter.java`](/mnt/c/Users/Wadet/Documents/FPGA_Projects/realprobe_plus/rapidwright_realprobe_inserter/RealProbeInserter.java)
- [`run_inserter.sh`](/mnt/c/Users/Wadet/Documents/FPGA_Projects/realprobe_plus/rapidwright_realprobe_inserter/run_inserter.sh)
- [`template.properties`](/mnt/c/Users/Wadet/Documents/FPGA_Projects/realprobe_plus/rapidwright_realprobe_inserter/template.properties)
- [`reference-example.properties`](/mnt/c/Users/Wadet/Documents/FPGA_Projects/realprobe_plus/rapidwright_realprobe_inserter/reference-example.properties)

## Usage

Start from the template, fill in the hierarchy names and DCP paths for your design, then run:

```bash
cd rapidwright_realprobe_inserter
./run_inserter.sh template.properties
```

If you already have a Vivado `write_edif` export of the original checkpoint, you may point `original_readable_edif` at it. If that `.edf` does not have the required `.edn` sidecar files next to it, `run_inserter.sh` will automatically regenerate a complete readable export under the output directory and use that instead.

If your RapidWright checkout lives next to `realprobe_plus` as `../RapidWright`, the helper script will discover it automatically.

You can override any property on the command line:

```bash
./run_inserter.sh template.properties \
  --output-dcp ./output/my_design_with_realprobe.dcp \
  --realprobe-instance-name realprobe_ip_0
```

To keep only the intermediate RapidWright output and skip the final Vivado-native rewrite:

```bash
FINALIZE_VIVADO=0 ./run_inserter.sh template.properties
```

## Notes

- This is separate from the normal RealProbe HLS flow.
- The output is still a full-design checkpoint, not an isolated subdesign checkpoint.
- The optional LUT reconstruction is intended for cases like the original reference flow where the desired probe source is not already exposed as a clean top-level port.
- The wrapper keeps the intermediate RapidWright artifacts so you can inspect them:
  - `*_rapidwright.dcp`
  - `*_rapidwright_load.tcl`
  - `.readable_edif/`
- If you skip finalization with `FINALIZE_VIVADO=0`, load the RapidWright checkpoint with `source *_rapidwright_load.tcl` instead of bare `open_checkpoint`.
