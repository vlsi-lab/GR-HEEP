# Copyright 2026 EPFL, Politecnico di Torino, and Universidad Politecnica de Madrid.
# Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Author: Michele Caon, Luigi Giuffrida, Daniel Vázquez, David Mallasén
# Description: Top-level makefile for GR-HEEP

# Global configuration
ROOT_DIR		:= $(realpath .)
X_HEEP_DIR 		:= $(ROOT_DIR)/hw/vendor/x-heep
BUILD_DIR 		:= build
SW_BUILD_DIR	:= sw/build

FUSESOC_BUILD_DIR = $(shell find $(BUILD_DIR) -maxdepth 1 -type d -name 'x-heep_systems_gr-heep_*' 2>/dev/null | sort -V | head -n 1)
VERILATOR_DIR     = $(FUSESOC_BUILD_DIR)/sim-verilator
QUESTASIM_DIR     = $(FUSESOC_BUILD_DIR)/sim-modelsim

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

# Implementation specific variables
# TARGET options are 'asic' (default), 'pynq-z2', 'nexys-a7-100t', 'genesys2', 'aup-zu3', 'zcu102', and 'zcu104'
TARGET ?= asic

# X-HEEP mcu-gen configuration
X_HEEP_CFG  		?= $(ROOT_DIR)/config/mcu-gen-config.py
PADS_CFG_ASIC		?= $(ROOT_DIR)/config/gr-heep_pad_cfg.py
PADS_CFG_FPGA		?= $(ROOT_DIR)/config/gr-heep_pad_cfg.py  # Currently the same as ASIC, but can be different if needed in the future
EXTERNAL_DOMAINS	:= 0 # TO BE UPDATED according to the number of external domains. FIXME: move to mcu-gen

ifeq ($(TARGET),asic)
	PADS_CFG := $(PADS_CFG_ASIC)
else ifeq ($(filter $(TARGET),pynq-z2 nexys-a7-100t genesys2 aup-zu3 zcu102 zcu104),$(TARGET))
	PADS_CFG := $(PADS_CFG_FPGA)
else
	$(error ### ERROR: Unsupported target implementation: $(TARGET))
endif

# Verilog format and linting variables
RTL_FILES := $(wildcard hw/gr-heep/*.sv)
# GR-HEEP templated files
# Collects all .tpl files in the project excluding certain directories
GR_HEEP_GEN_TPLS := $(shell find . \( -path './hw/vendor' -o -path './hw/fpga' -o -path './sw/device' -o -path './sw/linker' \) -prune -o -name '*.tpl' -print)
EXTERNAL_MCU_GEN_TEMPLATES = $(addprefix $(HEEP_REL_PATH)/,$(GR_HEEP_GEN_TPLS))

# Testing flags
# Optional TEST_FLAGS options are '--compile-only'
TEST_FLAGS=

# Software
PROJECT := hello_world

# Vendor
MODULE_NAME ?= x-heep

.PHONY: verible
verible:
	@for file in $(RTL_FILES); do \
		verible-verilog-format $$file --inplace \
			--formal_parameters_indentation indent --named_parameter_indentation indent \
			--named_port_indentation indent --port_declarations_indentation indent 2> /dev/null; \
		verible-verilog-lint $$file --lint_fatal=false --parse_fatal=false; \
	done

## Runs black formating for python files
format-python:
	$(PYTHON) -m black config
	$(PYTHON) -m black test

## @section RTL & SW generation

## Generate X-HEEP MCU files
.PHONY: mcu-gen
mcu-gen: | $(BUILD_DIR)/
	@echo "### Building X-HEEP MCU for '$(TARGET)'..."
	$(MAKE) -f $(XHEEP_MAKE) mcu-gen \
		X_HEEP_CFG=$(X_HEEP_CFG) \
		PADS_CFG=$(PADS_CFG) \
		EXTERNAL_DOMAINS=$(EXTERNAL_DOMAINS) \
		EXTERNAL_MCU_GEN_TEMPLATES="$(EXTERNAL_MCU_GEN_TEMPLATES)"
	$(MAKE) verible
	@echo "✅ DONE! X-HEEP MCU and GR-HEEP generated successfully"

## @section Verilator

## Verilator simulation with C++
.PHONY: verilator-build
verilator-build:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) \
		--build x-heep:systems:gr-heep $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## First builds the app and then uses Verilator to simulate the HW model and run the FW
.PHONY: verilator-run-app
verilator-run-app:
	$(MAKE) app
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) \
		--run x-heep:systems:gr-heep $(FUSESOC_PARAM) \
		--run_options="+firmware=../../../sw/build/main.hex $(SIM_ARGS)"

## Launches the RTL simulation with the compiled firmware (`app` target) using
## the C++ Verilator model previously built (`verilator-build` target).
.PHONY: verilator-run
verilator-run:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) \
		--run x-heep:systems:gr-heep $(FUSESOC_PARAM) \
		--run_options="+firmware=../../../sw/build/main.hex $(SIM_ARGS)"

## @section Questasim

## Questasim simulation
.PHONY: questasim-build
questasim-build:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=modelsim $(FUSESOC_FLAGS) \
		--build x-heep:systems:gr-heep $(FUSESOC_PARAM) 2>&1 | tee buildsim.log

## Questasim simulation with HDL optimized compilation
.PHONY: questasim-build-opt
questasim-build-opt: questasim-build
	$(MAKE) -C $(QUESTASIM_DIR) opt

## Launches the RTL simulation with the compiled firmware (`app` target) using
## the Questasim model previously built (`questasim-build` target).
questasim-run: 
	$(MAKE) -C $(QUESTASIM_DIR) run PLUSARGS="c firmware=../../../sw/build/main.hex"
	@echo -e "\033[1m### DONE! Simulation finished. UART output:\033[0m"
	@cat $(QUESTASIM_DIR)/uart0.log

## First builds the app and then uses Questasim to simulate the HW model and run the FW
.PHONY: questasim-run-app
questasim-run-app:
	$(MAKE) app
	$(MAKE) -C $(QUESTASIM_DIR) run PLUSARGS="c firmware=../../../sw/build/main.hex"
	@echo -e "\033[1m### DONE! Simulation finished. UART output:\033[0m"
	@cat $(QUESTASIM_DIR)/uart0.log

## Launches the RTL simulation with the compiled firmware (`app` target) using
## the Questasim model with HDL optimized compilation previously built (`questasim-build-opt` target).
questasim-run-opt: 
	$(MAKE) -C $(QUESTASIM_DIR) run RUN_OPT=1 PLUSARGS="c firmware=../../../sw/build/main.hex"
	@echo -e "\033[1m### DONE! Simulation finished. UART output:\033[0m"
	@cat $(QUESTASIM_DIR)/uart0.log

## First builds the app and then uses Questasim to simulate the HW model and run the FW
.PHONY: questasim-run-opt-app
questasim-run-opt-app:
	$(MAKE) app
	$(MAKE) -C $(QUESTASIM_DIR) run RUN_OPT=1 PLUSARGS="c firmware=../../../sw/build/main.hex"
	@echo -e "\033[1m### DONE! Simulation finished. UART output:\033[0m"
	@cat $(QUESTASIM_DIR)/uart0.log

.PHONY: questasim-run-app-gui
questasim-run-app-gui:
	$(MAKE) app
	$(MAKE) -C $(QUESTASIM_DIR) run-gui RUN_OPT=1 PLUSARGS="c firmware=../../../sw/build/main.hex"
	@echo -e "\033[1m### DONE! Simulation finished. UART output:\033[0m"
	@cat $(QUESTASIM_DIR)/uart0.log

## @section Vivado

## Builds (synthesis and implementation) the bitstream for the FPGA version using Vivado
## @param FPGA_BOARD=pynq-z2,nexys-a7-100t,genesys2,aup-zu3,zcu102,zcu104
## @param FUSESOC_FLAGS=--flag=<flagname>
vivado-fpga:
	$(FUSESOC) --cores-root . run --no-export --target=$(FPGA_BOARD) $(FUSESOC_FLAGS) \
		--build x-heep:systems:gr-heep $(FUSESOC_PARAM) 2>&1 | tee buildvivado.log

## Loads the generated bitstream into the FPGA
## @param FPGA_BOARD=pynq-z2,nexys-a7-100t,genesys2,aup-zu3,zcu102,zcu104
vivado-fpga-pgm:
	$(FUSESOC) --cores-root . run --no-export --target=$(FPGA_BOARD) $(FUSESOC_FLAGS) \
		--run x-heep:systems:gr-heep $(FUSESOC_PARAM) 2>&1 | tee programfpga.log

## @section Testing

## Run GR-HEEP tests
.PHONY: test
test: mcu-gen
	$(RM) test/*.log
	python test/gr_heep_test_apps.py $(TEST_FLAGS) 2>&1 | tee test/gr_heep_test_apps.log
	@echo "You can also find the output in test/gr_heep_test_apps.log"

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

## Create directories
%/:
	mkdir -p $@

# Export variables
export HEEP_DIR = $(X_HEEP_DIR)
export X_HEEP_CFG
export PADS_CFG
export EXTERNAL_DOMAINS
export XHEEP_CONFIG_CACHE
export PROJECT

# Include X-HEEP targets
XHEEP_MAKE = $(HEEP_DIR)/external.mk
ifneq ("$(wildcard $(XHEEP_MAKE))","")
	include $(XHEEP_MAKE)
endif
