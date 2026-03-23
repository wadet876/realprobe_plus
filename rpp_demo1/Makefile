.PHONY: base realprobe clean prebuild function check_env

SHELL := /bin/bash
.SHELLFLAGS := -lc

XILINX_ROOT ?= /home/htran304/tools/Xilinx
REALPROBE_PATH ?= $(abspath ../realprobe)
HLS_BUILD_PATH ?= $(XILINX_ROOT)/Vitis_HLS/2023.1/lnx64/tools/clang-3.9-csynth
VITIS_HLS ?= $(XILINX_ROOT)/Vitis_HLS/2023.1/bin/vitis_hls
VIVADO ?= $(XILINX_ROOT)/Vivado/2023.1/bin/vivado
AP_GCC_PATH ?= /usr/bin
EXTRA_LD_FLAGS ?= -no-pie
RUN_COSIM ?= 0
LOCPATH ?= /home/htran304/.local/usr/lib/locale
COMMON_LANG_ENV := LOCPATH=$(LOCPATH) LANG=en_US.UTF-8 LANGUAGE=en_US:en
VITIS_HLS_ENV := AP_GCC_PATH="$(AP_GCC_PATH)" ExtraLDFlags="$(EXTRA_LD_FLAGS)"
VITIS_LD_LIBRARY_PREFIX := $(XILINX_ROOT)/Vitis_HLS/2023.1/lib/lnx64.o:$(XILINX_ROOT)/Vitis_HLS/2023.1/lib/lnx64.o/SuSE
VIVADO_LD_LIBRARY_PREFIX := $(XILINX_ROOT)/Vivado/2023.1/lib/lnx64.o/SuSE:$(XILINX_ROOT)/Vivado/2023.1/lib/lnx64.o
VITIS_HLS_RUN := env $(COMMON_LANG_ENV) $(VITIS_HLS_ENV) LD_LIBRARY_PATH="$(VITIS_LD_LIBRARY_PREFIX):$${LD_LIBRARY_PATH}" "$(VITIS_HLS)"
VIVADO_RUN := env $(COMMON_LANG_ENV) LD_LIBRARY_PATH="$(VIVADO_LD_LIBRARY_PREFIX):$${LD_LIBRARY_PATH}" "$(VIVADO)"

HLS_FILE := hls.tcl
RP_HLS_FILE := .rp_hls.tcl
TMP_HLS_FILE := .tmp.tcl

clean:
	@rm -rf vivado FPGA project xcd.log vitis_hls.log
	@rm -rf .linux-hls-libs
	@rm -f $(RP_HLS_FILE) $(TMP_HLS_FILE) .rp_hls_test.tcl file*
	@rm -f $(REALPROBE_PATH)/vivado.tcl
	@rm -f $(REALPROBE_PATH)/basic_vivado.tcl

prebuild: clean

check_env:
	@if [ ! -d "$(REALPROBE_PATH)" ]; then \
		echo "Missing REALPROBE_PATH: $(REALPROBE_PATH)"; \
		exit 1; \
	fi
	@if [ ! -d "$(HLS_BUILD_PATH)" ]; then \
		echo "Missing HLS_BUILD_PATH: $(HLS_BUILD_PATH)"; \
		exit 1; \
	fi
	@if [ ! -f "$(HLS_BUILD_PATH)/bin/clang" ]; then \
		echo "Expected HLS frontend under $(HLS_BUILD_PATH)/bin"; \
		exit 1; \
	fi
	@if [ ! -x "$(VITIS_HLS)" ]; then \
		echo "Missing VITIS_HLS launcher: $(VITIS_HLS)"; \
		exit 1; \
	fi
	@if [ ! -x "$(VIVADO)" ]; then \
		echo "Missing VIVADO launcher: $(VIVADO)"; \
		exit 1; \
	fi
	@mkdir -p .linux-hls-libs
	@ln -sf "$(XILINX_ROOT)/Vitis_HLS/2023.1/lnx64/tools/clang-3.9/lib/libtinfo.so.5" ".linux-hls-libs/libtinfo.so.5"

base: prebuild check_env
	@$(eval PROJECT_NAME := $(shell awk -F"[ {}]+" '/^set project_name/ {print $$3}' $(HLS_FILE)))
	@$(eval SOLUTION_NAME := $(shell awk -F"[ {}]+" '/^set solution_name/ {print $$3}' $(HLS_FILE)))
	@awk '/^export_design/ { \
		print; \
		print "set arg1 \"'$(REALPROBE_PATH)'\""; \
		print "set arg2 $$project_name"; \
		print "set arg3 $$solution_name"; \
		print "set arg4 $$target_device"; \
		print "source '$(REALPROBE_PATH)'/basic_vivado_automate.tcl"; \
		next } { print }' $(HLS_FILE) > $(TMP_HLS_FILE)
	@sed -i 's/-code_analyzer[[:space:]]*//g' $(TMP_HLS_FILE)
	@if [ "$(RUN_COSIM)" != "1" ]; then sed -i '/^[[:space:]]*cosim_design[[:space:]]/d' $(TMP_HLS_FILE); fi
	@echo "unset arg1 arg2 arg3 arg4" >> $(TMP_HLS_FILE)
	$(VITIS_HLS_RUN) $(TMP_HLS_FILE)
	@mkdir -p vivado
	cd vivado && $(VIVADO_RUN) -mode batch -source ../$(PROJECT_NAME)/$(SOLUTION_NAME)/basic_vivado.tcl && cd ..
	@$(MAKE) setup_fpga

realprobe: prebuild check_env
	@awk '/^open_project/ { \
		print "set arg1 \"'$(REALPROBE_PATH)'\""; \
		print "set arg2 \"'$(HLS_BUILD_PATH)'\""; \
		print "set arg3 $$project_name"; \
		print "set arg4 $$solution_name"; \
		print "set arg5 $$target_device"; \
		print "source '$(REALPROBE_PATH)'/realprobe_run.tcl"; \
		print; next} {print}' $(HLS_FILE) > $(RP_HLS_FILE)
	@sed -i 's/-code_analyzer[[:space:]]*//g' $(RP_HLS_FILE)
	@if [ "$(RUN_COSIM)" != "1" ]; then sed -i '/^[[:space:]]*cosim_design[[:space:]]/d' $(RP_HLS_FILE); fi
	@echo "unset arg1 arg2 arg3 arg4 arg5" >> $(RP_HLS_FILE)
	$(VITIS_HLS_RUN) $(RP_HLS_FILE)
	@$(eval PROJECT_NAME := $(shell awk -F"[ {}]+" '/^set project_name/ {print $$3}' $(HLS_FILE)))
	@$(eval SOLUTION_NAME := $(shell awk -F"[ {}]+" '/^set solution_name/ {print $$3}' $(HLS_FILE)))
	@mkdir -p vivado
	cd vivado && $(VIVADO_RUN) -mode batch -source ../$(PROJECT_NAME)/$(SOLUTION_NAME)/rprobe/vivado.tcl && cd ..
	@$(MAKE) setup_fpga

function:
	@echo -n "" > top_updated.txt
	@echo $(filter-out $@,$(MAKECMDGOALS)) >> top_updated.txt
%:
	@:
	@$(eval PROJECT_NAME := $(shell awk -F"[ {}]+" '/^set project_name/ {print $$3}' $(HLS_FILE)))
	@$(eval SOLUTION_NAME := $(shell awk -F"[ {}]+" '/^set solution_name/ {print $$3}' $(HLS_FILE)))
	@echo "set arg1 \"$(REALPROBE_PATH)\"" > $(TMP_HLS_FILE)
	@echo "set arg2 $(PROJECT_NAME)" >> $(TMP_HLS_FILE)
	@echo "set arg3 $(SOLUTION_NAME)" >> $(TMP_HLS_FILE)
	@echo "source $(REALPROBE_PATH)/update_realprobeip.tcl" >> $(TMP_HLS_FILE)
	@echo "source $(REALPROBE_PATH)/update_vivado_automate.tcl" >> $(TMP_HLS_FILE)
	@echo "source $(REALPROBE_PATH)/update_ipynb_gen.tcl" >> $(TMP_HLS_FILE)
	@echo "unset arg1 arg2 arg3" >> $(TMP_HLS_FILE)
	$(VITIS_HLS_RUN) $(TMP_HLS_FILE)
	cd vivado && $(VIVADO_RUN) -mode batch -source ../$(PROJECT_NAME)/$(SOLUTION_NAME)/update_vivado.tcl && cd ..
	@$(MAKE) setup_fpga

setup_fpga:
	$(eval PROJECT_NAME := $(shell awk -F"[ {}]+" '/^set project_name/ {print $$3}' $(HLS_FILE)))
	$(eval SOLUTION_NAME := $(shell awk -F"[ {}]+" '/^set solution_name/ {print $$3}' $(HLS_FILE)))

	@mkdir -p FPGA
	@cp "vivado/$(PROJECT_NAME).runs/impl_1/design_1_wrapper.bit" "FPGA/design_1.bit"
	@cp "vivado/$(PROJECT_NAME).gen/sources_1/bd/design_1/hw_handoff/design_1.hwh" "FPGA/"
	@cp "./$(PROJECT_NAME)/$(SOLUTION_NAME)/rprobe/fpga.ipynb" "FPGA/"
