/*
 *
 * Copyright (c) 2025, Advanced Micro Devices, Inc.
 * All rights reserved.
 *
 * Author: Chris Lavin, AMD Research and Advanced Development.
 *
 * This file is part of RapidWright.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */
package com.xilinx.rapidwright.examples;

import com.xilinx.rapidwright.design.Design;
import com.xilinx.rapidwright.design.DesignTools;
import com.xilinx.rapidwright.design.Unisim;
import com.xilinx.rapidwright.design.tools.LUTTools;
import com.xilinx.rapidwright.edif.EDIFCell;
import com.xilinx.rapidwright.edif.EDIFCellInst;
import com.xilinx.rapidwright.edif.EDIFHierCellInst;
import com.xilinx.rapidwright.edif.EDIFHierNet;
import com.xilinx.rapidwright.edif.EDIFHierPortInst;
import com.xilinx.rapidwright.edif.EDIFNet;
import com.xilinx.rapidwright.edif.EDIFNetlist;
import com.xilinx.rapidwright.edif.EDIFPort;
import com.xilinx.rapidwright.edif.EDIFPortInst;
import com.xilinx.rapidwright.edif.EDIFTools;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

/**
 * Parameterized RapidWright-based RealProbe DCP inserter.
 */
public class RealProbeInserter {
    private static class Options {
        String originalDcp;
        String originalReadableEdif = "";
        String realProbeDcp;
        String bramCtrlDcp;
        String outputDcp;
        String topCellInst;
        String realProbeSourceInst = "inst";
        String bramCtrlSourceInst = "U0";
        String realProbeInstanceName = "realprobe_ip_0";
        String bramCtrlInstanceName = "axi_bram_ctrl_0";
        String realProbeDataPort = "axi_rdata_32b";
        String bramCtrlDataPort = "bram_rddata_a";
        int dataWidth = 32;
        String busNetPrefix = "realprobe_ip_0_axi_rdata_32b";
        String realProbeProbePort = "";
        String probeNetName = "";
        String lutParentHier = "";
        String lutInstanceName = "ap_done_out_INST_0";
        String lutEquation = "O=I0 & I1";
        String lutInput0Net = "";
        String lutInput1Net = "";
        String lutOutputPort = "O";
    }

    public static void main(String[] args) {
        try {
            if (args.length == 0 || hasFlag(args, "--help")) {
                printUsage();
                return;
            }

            Options options = parseOptions(args);
            insertRealProbe(options);
        } catch (Exception e) {
            System.err.println("RapidWright RealProbe insertion failed: " + e.getMessage());
            e.printStackTrace(System.err);
            System.exit(1);
        }
    }

    private static void insertRealProbe(Options options) {
        Design original = options.originalReadableEdif.isEmpty()
                ? Design.readCheckpoint(options.originalDcp)
                : Design.readCheckpoint(options.originalDcp, options.originalReadableEdif);
        Design realProbeIP = Design.readCheckpoint(options.realProbeDcp);
        Design bramCtrl = Design.readCheckpoint(options.bramCtrlDcp);

        EDIFNetlist netlist = original.getNetlist();
        EDIFTools.uniqueifyNetlist(original);

        EDIFCellInst topCellInst = original.getTopEDIFCell().getCellInst(options.topCellInst);
        if (topCellInst == null) {
            throw new IllegalArgumentException("Could not find top cell instance '" + options.topCellInst + "'");
        }
        EDIFCell top = topCellInst.getCellType();

        EDIFCellInst srcRealProbeInst = requireSourceInst(realProbeIP, options.realProbeSourceInst);
        EDIFCellInst srcBramCtrlInst = requireSourceInst(bramCtrl, options.bramCtrlSourceInst);

        netlist.copyCellAndSubCells(srcRealProbeInst.getCellType());
        netlist.copyCellAndSubCells(srcBramCtrlInst.getCellType());

        EDIFCellInst realProbeInst = top.createChildCellInst(
                options.realProbeInstanceName,
                netlist.getCell(srcRealProbeInst.getCellType().getName())
        );
        EDIFCellInst bramCtrlInst = top.createChildCellInst(
                options.bramCtrlInstanceName,
                netlist.getCell(srcBramCtrlInst.getCellType().getName())
        );

        DesignTools.copyImplementation(
                realProbeIP,
                original,
                false,
                false,
                mapOf(
                        options.realProbeSourceInst,
                        options.topCellInst + "/" + options.realProbeInstanceName
                )
        );
        DesignTools.copyImplementation(
                bramCtrl,
                original,
                false,
                false,
                mapOf(
                        options.bramCtrlSourceInst,
                        options.topCellInst + "/" + options.bramCtrlInstanceName
                )
        );

        netlist.resetParentNetMap();

        EDIFPort src = requirePort(realProbeInst, options.realProbeDataPort);
        EDIFPort snk = requirePort(bramCtrlInst, options.bramCtrlDataPort);
        for (int i = 0; i < options.dataWidth; i++) {
            EDIFNet net = top.createNet(options.busNetPrefix + "[" + i + "]");
            net.createPortInst(src, i, realProbeInst);
            net.createPortInst(snk, i, bramCtrlInst);
        }

        if (hasLutProbe(options)) {
            EDIFHierCellInst targetParent = requireHierCellInst(netlist, options.lutParentHier);
            EDIFCellInst lut2 = targetParent.getCellType().createChildCellInst(
                    options.lutInstanceName,
                    netlist.getHDIPrimitive(Unisim.LUT2)
            );
            LUTTools.configureLUT(lut2, options.lutEquation);
            requireNet(targetParent, options.lutInput0Net).getNet().createPortInst("I0", lut2);
            requireNet(targetParent, options.lutInput1Net).getNet().createPortInst("I1", lut2);

            EDIFHierCellInst hierRealProbeParent = requireHierCellInst(netlist, options.topCellInst);
            EDIFHierPortInst realProbePort = new EDIFHierPortInst(
                    hierRealProbeParent,
                    getOrCreatePortInst(realProbeInst, options.realProbeProbePort)
            );
            EDIFHierPortInst lutOutput = new EDIFHierPortInst(
                    targetParent,
                    getOrCreatePortInst(lut2, options.lutOutputPort)
            );
            EDIFTools.connectPortInstsThruHier(lutOutput, realProbePort, options.probeNetName);
        }

        File outputFile = new File(options.outputDcp);
        File outputParent = outputFile.getAbsoluteFile().getParentFile();
        if (outputParent != null && !outputParent.exists()) {
            outputParent.mkdirs();
        }
        original.writeCheckpoint(options.outputDcp);
        relocateLoadScript(outputFile.toPath());
        System.out.println("Wrote checkpoint: " + options.outputDcp);
        if (!original.getNetlist().getEncryptedCells().isEmpty()) {
            System.out.println(
                    "Use the generated *_load.tcl script to open this checkpoint in Vivado so encrypted IP netlists are restored."
            );
        }
    }

    private static boolean hasFlag(String[] args, String flag) {
        for (String arg : args) {
            if (flag.equals(arg)) {
                return true;
            }
        }
        return false;
    }

    private static Options parseOptions(String[] args) throws IOException {
        Properties properties = new Properties();

        for (int i = 0; i < args.length; i++) {
            if ("--config".equals(args[i])) {
                ensureValue(args, i);
                try (FileInputStream in = new FileInputStream(args[++i])) {
                    properties.load(in);
                }
            }
        }

        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            if (!arg.startsWith("--")) {
                continue;
            }
            if ("--config".equals(arg) || "--help".equals(arg)) {
                if ("--config".equals(arg)) {
                    i++;
                }
                continue;
            }
            ensureValue(args, i);
            properties.setProperty(flagToProperty(arg), args[++i]);
        }

        Options options = new Options();
        options.originalDcp = requireProperty(properties, "original_dcp");
        options.originalReadableEdif = properties.getProperty(
                "original_readable_edif",
                options.originalReadableEdif
        ).trim();
        options.realProbeDcp = requireProperty(properties, "realprobe_dcp");
        options.bramCtrlDcp = requireProperty(properties, "bram_ctrl_dcp");
        options.outputDcp = requireProperty(properties, "output_dcp");
        options.topCellInst = requireProperty(properties, "top_cell_inst");

        options.realProbeSourceInst = properties.getProperty("realprobe_source_inst", options.realProbeSourceInst);
        options.bramCtrlSourceInst = properties.getProperty("bram_ctrl_source_inst", options.bramCtrlSourceInst);
        options.realProbeInstanceName = properties.getProperty("realprobe_instance_name", options.realProbeInstanceName);
        options.bramCtrlInstanceName = properties.getProperty("bram_ctrl_instance_name", options.bramCtrlInstanceName);
        options.realProbeDataPort = properties.getProperty("realprobe_data_port", options.realProbeDataPort);
        options.bramCtrlDataPort = properties.getProperty("bram_ctrl_data_port", options.bramCtrlDataPort);
        options.dataWidth = Integer.parseInt(properties.getProperty("data_width", Integer.toString(options.dataWidth)));
        options.busNetPrefix = properties.getProperty("bus_net_prefix", options.busNetPrefix);
        options.realProbeProbePort = properties.getProperty("realprobe_probe_port", options.realProbeProbePort).trim();
        options.probeNetName = properties.getProperty("probe_net_name", options.probeNetName).trim();
        options.lutParentHier = properties.getProperty("lut_parent_hier", options.lutParentHier).trim();
        options.lutInstanceName = properties.getProperty("lut_instance_name", options.lutInstanceName);
        options.lutEquation = properties.getProperty("lut_equation", options.lutEquation);
        options.lutInput0Net = properties.getProperty("lut_input0_net", options.lutInput0Net).trim();
        options.lutInput1Net = properties.getProperty("lut_input1_net", options.lutInput1Net).trim();
        options.lutOutputPort = properties.getProperty("lut_output_port", options.lutOutputPort);

        if (options.dataWidth <= 0) {
            throw new IllegalArgumentException("data_width must be greater than zero");
        }
        if (!hasLutProbe(options) && hasAnyProbeField(options)) {
            throw new IllegalArgumentException(
                    "Incomplete LUT probe configuration. Set realprobe_probe_port, probe_net_name, " +
                    "lut_parent_hier, lut_input0_net, and lut_input1_net, or leave all probe fields blank."
            );
        }
        return options;
    }

    private static boolean hasLutProbe(Options options) {
        return !options.realProbeProbePort.isEmpty()
                && !options.probeNetName.isEmpty()
                && !options.lutParentHier.isEmpty()
                && !options.lutInput0Net.isEmpty()
                && !options.lutInput1Net.isEmpty();
    }

    private static boolean hasAnyProbeField(Options options) {
        return !options.realProbeProbePort.isEmpty()
                || !options.probeNetName.isEmpty()
                || !options.lutParentHier.isEmpty()
                || !options.lutInput0Net.isEmpty()
                || !options.lutInput1Net.isEmpty();
    }

    private static void ensureValue(String[] args, int flagIndex) {
        if (flagIndex + 1 >= args.length) {
            throw new IllegalArgumentException("Missing value for " + args[flagIndex]);
        }
    }

    private static String flagToProperty(String arg) {
        return arg.substring(2).replace('-', '_');
    }

    private static String requireProperty(Properties properties, String key) {
        String value = properties.getProperty(key);
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalArgumentException("Missing required property: " + key);
        }
        return value.trim();
    }

    private static void relocateLoadScript(Path outputDcp) {
        String fileName = outputDcp.getFileName().toString();
        int dot = fileName.lastIndexOf('.');
        String baseName = dot >= 0 ? fileName.substring(0, dot) : fileName;
        Path generated = Path.of(baseName + EDIFTools.LOAD_TCL_SUFFIX);
        if (!Files.exists(generated)) {
            return;
        }

        Path outputDir = outputDcp.toAbsolutePath().getParent();
        if (outputDir == null) {
            return;
        }

        Path target = outputDir.resolve(generated.getFileName());
        try {
            Files.move(generated, target, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            throw new RuntimeException("Failed to move load script to " + target, e);
        }
    }

    private static EDIFCellInst requireSourceInst(Design design, String hierName) {
        EDIFHierCellInst hierInst = design.getNetlist().getHierCellInstFromName(hierName);
        if (hierInst != null && hierInst.getInst() != null) {
            return hierInst.getInst();
        }
        EDIFCellInst inst = design.getTopEDIFCell().getCellInst(hierName);
        if (inst != null) {
            return inst;
        }
        throw new IllegalArgumentException(
                "Could not find source instance '" + hierName + "' in design '" + design.getName() + "'"
        );
    }

    private static EDIFPort requirePort(EDIFCellInst cellInst, String portName) {
        EDIFPort port = cellInst.getPort(portName);
        if (port == null) {
            throw new IllegalArgumentException(
                    "Could not find port '" + portName + "' on instance '" + cellInst.getName() + "'"
            );
        }
        return port;
    }

    private static EDIFPortInst getOrCreatePortInst(EDIFCellInst cellInst, String portName) {
        EDIFPortInst portInst = cellInst.getPortInst(portName);
        if (portInst != null) {
            return portInst;
        }
        return new EDIFPortInst(requirePort(cellInst, portName), null, cellInst);
    }

    private static EDIFHierCellInst requireHierCellInst(EDIFNetlist netlist, String hierName) {
        EDIFHierCellInst cellInst = netlist.getHierCellInstFromName(hierName);
        if (cellInst == null) {
            throw new IllegalArgumentException("Could not find hierarchy cell instance '" + hierName + "'");
        }
        return cellInst;
    }

    private static EDIFHierNet requireNet(EDIFHierCellInst parent, String netName) {
        EDIFHierNet net = parent.getNet(netName);
        if (net == null) {
            throw new IllegalArgumentException(
                    "Could not find net '" + netName + "' under hierarchy '" + parent.getFullHierarchicalInstName() + "'"
            );
        }
        return net;
    }

    private static Map<String, String> mapOf(String key, String value) {
        Map<String, String> map = new HashMap<>();
        map.put(key, value);
        return map;
    }

    private static void printUsage() {
        System.out.println("Usage:");
        System.out.println("  RealProbeInserter --config <file.properties> [--key value ...]");
        System.out.println("");
        System.out.println("Required properties:");
        System.out.println("  original_dcp, realprobe_dcp, bram_ctrl_dcp, output_dcp, top_cell_inst");
        System.out.println("");
        System.out.println("Optional properties:");
        System.out.println("  realprobe_source_inst, bram_ctrl_source_inst");
        System.out.println("  realprobe_instance_name, bram_ctrl_instance_name");
        System.out.println("  realprobe_data_port, bram_ctrl_data_port, data_width, bus_net_prefix");
        System.out.println("  realprobe_probe_port, probe_net_name, lut_parent_hier");
        System.out.println("  lut_instance_name, lut_equation, lut_input0_net, lut_input1_net, lut_output_port");
    }
}
