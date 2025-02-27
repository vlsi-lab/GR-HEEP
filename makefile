# Copyright 2024 Politecnico di Torino.
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# File: makefile
# Author: Luigi Giuffrida
# Date: 03/10/2024
# Description: Top-level makefile for gr-HEEP
# ATTENTION: This file is just a template. It is not meant to be used as is.
#            Please replace all references to "GR-HEEP" with the name of your project.

# ----- CONFIGURATION ----- #

# Global configuration
ROOT_DIR			:= $(realpath .)
BUILD_DIR 			:= build
SW_BUILD_DIR		:= sw/build

# FUSESOC and Python values (default)
ifndef CONDA_DEFAULT_ENV
$(info USING VENV)
FUSESOC = ./.venv/bin/fusesoc
PYTHON  = ./.venv/bin/python
else
$(info USING MINICONDA $(CONDA_DEFAULT_ENV))
FUSESOC := $(shell which fusesoc)
PYTHON  := $(shell which python)
endif

# X-HEEP configuration
XHEEP_DIR			:= $(ROOT_DIR)/hw/vendor/x-heep
LINK_FOLDER			:= $(XHEEP_DIR)/sw/linker
MCU_CFG_PERIPHERALS ?= $(ROOT_DIR)/config/mcu-gen.hjson
X_HEEP_CFG  		?= $(ROOT_DIR)/config/mcu-gen-system.hjson
PAD_CFG				?= $(ROOT_DIR)/config/x-heep-pads.hjson
EXT_PAD_CFG			?= $(ROOT_DIR)/config/gr-heep-pads.hjson
EXTERNAL_DOMAINS	:= 0 # TO BE UPDATED according to the number of external domains
MCU_GEN_OPTS		:= \
	--memorybanks $(MEMORY_BANKS) \
	--memorybanks_il $(MEMORY_BANKS_IL) \
	--bus $(BUS) \
	--config $(X_HEEP_CFG) \
	--cfg_peripherals $(MCU_CFG_PERIPHERALS) \
	--pads_cfg $(PAD_CFG) \
	--external_domains $(EXTERNAL_DOMAINS)

GR_HEEP_TOP_TPL		:= $(ROOT_DIR)/hw/top/gr_heep_top.sv.tpl
# PAD_RING_TPL		:= $(ROOT_DIR)/hw/pad-ring/pad_ring.sv.tpl
MCU_GEN_LOCK		:= $(BUILD_DIR)/.mcu-gen.lock

# gr-HEEP configuration
GR_HEEP_GEN_CFG	 := config/gr-heep-cfg.hjson
GR_HEEP_GEN_OPTS := \
	--cfg $(GR_HEEP_GEN_CFG)
GR_HEEP_GEN_LOCK := build/.gr-heep-gen.lock

# Simulation DPI libraries
DPI_LIBS			:= $(BUILD_DIR)/sw/sim/uartdpi.so
DPI_CINC			:= -I$(dir $(shell which verilator))../share/verilator/include/vltstd

# Simulation configuration
VERILATOR_VERSION   ?= $(shell verilator --version | grep -oP 'Verilator \K[0-9]+')
LOG_LEVEL			?= LOG_NORMAL
BOOT_MODE			?= force # jtag: wait for JTAG (DPI module), flash: boot from flash, force: load firmware into SRAM
FIRMWARE			?= $(ROOT_DIR)/build/sw/app/main.hex
VCD_MODE			?= 0 # QuestaSim-only - 0: no dumo, 1: dump always active, 2: dump triggered by GPIO 0
MAX_CYCLES			?= 1200000
FUSESOC_FLAGS		?=
FUSESOC_ARGS		?=

# Flash file
FLASHWRITE_FILE		?= $(FIRMWARE)

# QuestaSim
FUSESOC_BUILD_DIR			= $(shell find $(BUILD_DIR) -type d -name 'polito_gr_heep_gr_heep_*' 2>/dev/null | sort | head -n 1)
QUESTA_SIM_DIR				= $(FUSESOC_BUILD_DIR)/sim-modelsim

# Application spacific makefile
APP_MAKE := $(wildcard sw/applications/$(PROJECT)/*akefile)

# Custom preprocessor definitions
CDEFS ?=

# Software build configuration
SW_DIR := sw

# Dummy target to force software rebuild
PARAMS = $(PROJECT)

# Arch for the software build
ARCH ?= rv32imc

# ----- VARIABLES ----- #

MODULE_NAME ?= x-heep

# ----- BUILD RULES ----- #


# Get the path of this Makefile to pass to the Makefile help generator
MKFILE_PATH = $(shell dirname "$(realpath $(firstword $(MAKEFILE_LIST)))")
export FILE_FOR_HELP = $(MKFILE_PATH)/makefile
export XHEEP_DIR


## Print the Makefile help
## @param WHICH=xheep,all,<none> Which Makefile help to print. Leaving blank (<none>) prints only gr-HEEP's.
help:
ifndef WHICH
	${XHEEP_DIR}/util/MakefileHelp
else ifeq ($(filter $(WHICH),xheep x-heep),)
	${XHEEP_DIR}/util/MakefileHelp
	$(MAKE) -C $(XHEEP_DIR) help
else
	$(MAKE) -C $(XHEEP_DIR) help
endif

# Default alias
# -------------
.PHONY: all
all: gr-heep-gen

## @section RTL & SW generation

## X-HEEP MCU system
.PHONY: mcu-gen
mcu-gen: $(MCU_GEN_LOCK)
$(MCU_GEN_LOCK): $(MCU_CFG) $(PAD_CFG) $(EXT_PAD_CFG) | $(BUILD_DIR)/
	@echo "### Building X-HEEP MCU..."
	$(MAKE) -f $(XHEEP_MAKE) mcu-gen
	touch $@
	$(RM) -f $(GR_HEEP_GEN_LOCK)
	@echo "### DONE! X-HEEP MCU generated successfully"

.PHONY: gr-heep-gen-force
gr-heep-gen-force:
	rm -rf build/.mcu-gen.lock build/.gr-heep-gen.lock;
	$(MAKE) gr-heep-gen

## Generate gr-HEEP files
.PHONY: gr-heep-gen
gr-heep-gen: $(GR_HEEP_GEN_LOCK)
$(GR_HEEP_GEN_LOCK): $(GR_HEEP_GEN_CFG) $(GR_HEEP_TOP_TPL) $(MCU_GEN_LOCK)
	@echo "### Generating gr-HEEP top and pad rings..."
	python3 $(XHEEP_DIR)/util/mcu_gen.py $(MCU_GEN_OPTS) \
		--outdir $(ROOT_DIR)/hw/top/ \
		--external_pads $(EXT_PAD_CFG) \
		--tpl-sv $(GR_HEEP_TOP_TPL)
	python3 $(XHEEP_DIR)/util/mcu_gen.py $(MCU_GEN_OPTS) \
		--outdir $(ROOT_DIR)/hw/pad-ring/ \
		--external_pads $(EXT_PAD_CFG) \
		--tpl-sv $(ROOT_DIR)/hw/pad-ring/pad_ring.sv.tpl
	python3 $(XHEEP_DIR)/util/mcu_gen.py $(MCU_GEN_OPTS) \
		--outdir $(ROOT_DIR)/tb/ \
		--external_pads $(EXT_PAD_CFG) \
		--tpl-sv $(ROOT_DIR)/tb/tb_util.svh.tpl
	@echo "### Generating gr-HEEP files..."
	python3 util/gr-heep-gen.py $(GR_HEEP_GEN_OPTS) \
		--outdir hw/packages \
		--tpl-sv hw/packages/gr_heep_pkg.sv.tpl \
		--corev_pulp $(COREV_PULP)
	python3 util/gr-heep-gen.py $(GR_HEEP_GEN_OPTS) \
		--outdir hw/peripherals \
		--tpl-sv hw/peripherals/gr_heep_peripherals.sv.tpl
	python3 util/gr-heep-gen.py $(GR_HEEP_GEN_OPTS) \
		--outdir sw/external/lib/runtime \
		--tpl-c sw/external/lib/runtime/gr_heep.h.tpl
	$(FUSESOC) run --no-export --target lint polito:gr_heep:gr_heep
	$(FUSESOC) run --no-export --target format polito:gr_heep:gr_heep
	@echo "### DONE! gr-HEEP files generated successfully"
	touch $@

## @section Simulation

## @subsection Verilator RTL simulation

## Build simulation model (do not launch simulation)
.PHONY: verilator-build
verilator-build: $(GR_HEEP_GEN_LOCK)
	$(FUSESOC) run --no-export --target sim --tool verilator --build $(FUSESOC_FLAGS) polito:gr_heep:gr_heep \
		$(FUSESOC_ARGS)

## Build simulation model and launch simulation
.PHONY: verilator-sim
verilator-sim: | check-firmware verilator-build .verilator-check-params
	$(FUSESOC) run --no-export --target sim --tool verilator --run $(FUSESOC_FLAGS) polito:gr_heep:gr_heep \
		--log_level=$(LOG_LEVEL) \
		--firmware=$(FIRMWARE) \
		--boot_mode=$(BOOT_MODE) \
		--max_cycles=$(MAX_CYCLES) \
		--trace=true \
		$(FUSESOC_ARGS)
	cat $(FUSESOC_BUILD_DIR)/sim-verilator/uart.log

## Launch simulation
.PHONY: verilator-run
verilator-run: | check-firmware .verilator-check-params
	$(FUSESOC) run --no-export --target sim --tool verilator --run $(FUSESOC_FLAGS) polito:gr_heep:gr_heep \
		--log_level=$(LOG_LEVEL) \
		--firmware=$(FIRMWARE) \
		--boot_mode=$(BOOT_MODE) \
		--max_cycles=$(MAX_CYCLES) \
		--trace=true \
		$(FUSESOC_ARGS)
	cat $(FUSESOC_BUILD_DIR)/sim-verilator/uart.log

## Launch simulation without waveform dumping
.PHONY: verilator-opt
verilator-opt: | check-firmware .verilator-check-params
	$(FUSESOC) run --no-export --target sim --tool verilator --run $(FUSESOC_FLAGS) polito:gr_heep:gr_heep \
		--log_level=$(LOG_LEVEL) \
		--firmware=$(FIRMWARE) \
		--boot_mode=$(BOOT_MODE) \
		--max_cycles=$(MAX_CYCLES) \
		--trace=false \
		$(FUSESOC_ARGS)
	cat $(FUSESOC_BUILD_DIR)/sim-verilator/uart.log

## Open dumped waveform with GTKWave
.PHONY: verilator-waves
verilator-waves: $(BUILD_DIR)/sim-common/waves.fst | .check-gtkwave
	gtkwave -a tb/misc/verilator-waves.gtkw $<

## @section Software

## gr-HEEP applications
.PHONY: app
app: $(GR_HEEP_GEN_LOCK) | $(BUILD_DIR)/sw/app/
ifneq ($(APP_MAKE),)
	@echo "### Calling application-specific makefile '$(APP_MAKE)'..."
	$(MAKE) -C $(dir $(APP_MAKE))
endif
	@echo "### Building application for SRAM execution with GCC compiler..."
	CDEFS=$(CDEFS) $(MAKE) -f $(XHEEP_MAKE) $(MAKECMDGOALS) LINK_FOLDER=$(LINK_FOLDER) ARCH=$(ARCH)
	find $(SW_BUILD_DIR)/ -maxdepth 1 -type f -name "main.*" -exec cp '{}' $(BUILD_DIR)/sw/app/ \;

## Dummy target to force software rebuild
$(PARAMS):
	@echo "### Rebuilding software..."

## @section Utilities

## Update vendor submodules
## @note These targets are used to update the vendored submodules.
## @param MODULE_NAME=module_name The name of the submodule to update when using vendor-update.
.PHONY: vendor-update
vendor-update:
	@echo "Updating vendored module '$(MODULE_NAME)'..."
	$(PYTHON) util/vendor.py hw/vendor/$(MODULE_NAME).vendor.hjson -Uv

.PHONY: vendor-update-all
vendor-update-all:
	@echo "Updating all vendored modules..."
	find hw/vendor -maxdepth 1 -type f -name "*.vendor.hjson" -exec ./util/vendor.py -vU {} \;

## Check if the firmware is compiled
.PHONY: .check-firmware
check-firmware:
	@if [ ! -f $(FIRMWARE) ]; then \
		echo "\033[31mError: FIRMWARE has not been compiled! Simulation won't work!\033[0m"; \
		exit 1; \
	fi

## Check if fusesoc is available
.PHONY: .check-fusesoc
.check-fusesoc:
	@if [ ! `which fusesoc` ]; then \
	printf -- "### ERROR: 'fusesoc' is not in PATH. Is the correct conda environment active?\n" >&2; \
	exit 1; fi

# Check if GTKWave is available
.PHONY: .check-gtkwave
.check-gtkwave:
	@if [ ! `which gtkwave` ]; then \
	printf -- "### ERROR: 'gtkwave' is not in PATH. Is the correct conda environment active?\n" >&2; \
	exit 1; fi

## Check simulation parameters
.PHONY: .verilator-check-params
.verilator-check-params:
	@if [ "$(BOOT_MODE)" = "flash" ]; then \
		echo "### ERROR: Verilator simulation with flash boot is not supported" >&2; \
		exit 1; \
	fi

## Create directories
%/:
	mkdir -p $@


## @section Cleaning

## Clean build directory
.PHONY: clean clean-lock
clean:
	$(RM) $(GR_HEEP_GEN_LOCK)
	$(RM) hw/ip/gr_heep_top.sv
	$(RM) hw/ip/pad-ring/pad-ring.sv
	$(RM) sw/device/include/gr_heep.h
	$(RM) -r $(BUILD_DIR)
	$(MAKE) -C $(HEEP_DIR) clean-all
clean-lock:
	$(RM) $(BUILD_DIR)/.*.lock


## @section Format and Variables

## Verible format
.PHONY: format
format: $(GR_HEEP_GEN_LOCK)
	@echo "### Formatting gr-HEEP RTL files..."
	$(FUSESOC) run --no-export --target format polito:gr_heep:gr_heep

## Static analysis
.PHONY: lint
lint: $(GR_HEEP_GEN_LOCK)
	@echo "### Checking gr-HEEP syntax and code style..."
	$(FUSESOC) run --no-export --target lint polito:gr_heep:gr_heep

## Print variables
.PHONY: .print
.print:
	@echo "APP_MAKE: $(APP_MAKE)"
	@echo "KERNEL_PARAMS: $(KERNEL_PARAMS)"
	@echo "FUSESOC_ARGS: $(FUSESOC_ARGS)"


# ----- INCLUDE X-HEEP RULES ----- #
export X_HEEP_CFG
export MCU_CFG_PERIPHERALS
export PAD_CFG
export EXT_PAD_CFG
export EXTERNAL_DOMAINS
export FLASHWRITE_FILE
export HEEP_DIR = $(ROOT_DIR)/hw/vendor/x-heep
XHEEP_MAKE 		= $(HEEP_DIR)/external.mk
include $(XHEEP_MAKE)
