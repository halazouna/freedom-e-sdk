#############################################################
# Configuration
#############################################################

# Allows users to create Makefile.local or ../Makefile.project with
# configuration variables, so they don't have to be set on the command-line
# every time.
extra_configs := $(wildcard Makefile.local ../Makefile.project)
ifneq ($(extra_configs),)
$(info Obtaining additional make variables from $(extra_configs))
include $(extra_configs)
endif

# Allow BOARD as a synonym for TARGET
ifneq ($(BOARD),)
TARGET ?= $(BOARD)
endif

# Default PROGRAM and TARGET
PROGRAM ?= hello
TARGET ?= sifive-hifive1

TARGET_ROOT  ?= $(abspath .)
PROGRAM_ROOT ?= $(abspath .)

SRC_DIR = $(PROGRAM_ROOT)/software/$(PROGRAM)

PROGRAM_ELF = $(SRC_DIR)/$(PROGRAM)
PROGRAM_HEX = $(SRC_DIR)/$(PROGRAM).hex

#############################################################
# BSP Loading
#############################################################

# Finds the directory in which this BSP is located, ensuring that there is
# exactly one.
BSP_DIR := $(wildcard $(TARGET_ROOT)/bsp/$(TARGET))
ifeq ($(words $(BSP_DIR)),0)
$(error Unable to find BSP for $(TARGET), expected to find "bsp/$(TARGET)")
endif
ifneq ($(words $(BSP_DIR)),1)
$(error Found multiple BSPs for $(TARGET): "$(BSP_DIR)")
endif

#############################################################
# Standalone Script Include
#############################################################

# The standalone script is included here because it needs $(SRC_DIR) and
# $(BSP_DIR) to be set.
#
# The standalone Makefile handles the following tasks:
#  - Including $(BSP_DIR)/settings.mk and validating RISCV_ARCH, RISCV_ABI
#  - Setting the toolchain path with CROSS_COMPILE and RISCV_PATH
#  - Providing the software and $(PROGRAM_ELF) Make targets for Metal

include scripts/standalone.mk

#############################################################
# Prints help message
#############################################################
.PHONY: help
help:
	@echo " SiFive Freedom E Software Development Kit "
	@echo " Makefile targets:"
	@echo ""
	@echo " software [PROGRAM=$(PROGRAM)] [TARGET=$(TARGET)]"
	@echo "          [CONFIGURATION=$(CONFIGURATION)]:"
	@echo "    Builds the requested PROGRAM for the TARGET using the"
	@echo "    specified build CONFIGURATION."
	@echo ""
	@echo " metal [TARGET=$(TARGET)] [CONFIGURATION=$(CONFIGURATION)]"
	@echo "    Builds the Freedom Metal library for TARGET."
	@echo ""
	@echo " clean [PROGRAM=$(PROGRAM)] [TARGET=$(TARGET)]"
	@echo "       [CONFIGURATION=$(CONFIGURATION)]:"
	@echo "    Cleans compiled objects for a specified "
	@echo "    software program."
	@echo ""
	@echo " upload [PROGRAM=$(PROGRAM)] [TARGET=$(TARGET)]"
	@echo "        [CONFIGURATION=$(CONFIGURATION)]:"
	@echo "    For board and FPGA TARGETs, uploads the program to the"
	@echo "    on-board flash."
	@echo ""
	@echo " debug [PROGRAM=$(PROGRAM)] [TARGET=$(TARGET)]"
	@echo "       [CONFIGURATION=$(CONFIGURATION)]:"
	@echo "    For board and FPGA TARGETs, attaches GDB to the"
	@echo "    running program."
	@echo ""
	@echo " standalone STANDALONE_DEST=/path/to/desired/location"
	@echo "            [INCLUDE_METAL_SOURCES=1] [PROGRAM=$(PROGRAM)]"
	@echo "            [TARGET=$(TARGET)] [CONFIGURATION=$(CONFIGURATION)]:"
	@echo "    Exports a program for a single target into a standalone"
	@echo "    project directory at STANDALONE_DEST."
	@echo ""
	@echo " For more information, view the Freedom E SDK Documentation at"
	@echo "   https://sifive.github.io/freedom-e-sdk-docs/index.html"

.PHONY: clean
clean:

#############################################################
# Enumerate BSPs and Programs
#
# List all available boards and programs in a form that 
# Freedom Studio knows how to parse.  Do not change the 
# format or fixed text of the output without consulting the 
# Freedom Studio dev team.
#############################################################
#
# Metal boards are any folders that aren't the Legacy BSP or update-targets.sh
EXCLUDE_TARGET_DIRS = drivers env include libwrap update-targets.sh
list-targets:
	@echo bsp-list: $(sort $(filter-out $(EXCLUDE_TARGET_DIRS),$(notdir $(wildcard bsp/*))))

# Metal programs are any submodules in the software folder
list-programs:
	@echo program-list: $(shell grep -o '= software/.*$$' .gitmodules | sed 's/.*\///')

list-options: list-programs list-targets

#############################################################
# Import rules to build Freedom Metal
#############################################################

include scripts/libmetal.mk

#############################################################
# elf2hex
#############################################################
scripts/elf2hex/build/Makefile: scripts/elf2hex/configure
	@rm -rf $(dir $@)
	@mkdir -p $(dir $@)
	cd $(dir $@); \
		$(abspath $<) \
		--prefix=$(abspath $(dir $<))/install \
		--target=$(CROSS_COMPILE)

scripts/elf2hex/install/bin/$(CROSS_COMPILE)-elf2hex: scripts/elf2hex/build/Makefile
	$(MAKE) -C $(dir $<) install
	touch -c $@

.PHONY: clean-elf2hex
clean-elf2hex:
	rm -rf scripts/elf2hex/build scripts/elf2hex/install
clean: clean-elf2hex

#############################################################
# Standalone Project Export
#############################################################

ifeq ($(STANDALONE_DEST),)
standalone:
	$(error Please provide STANDALONE_DEST to create a standalone project)
else

$(STANDALONE_DEST):
$(STANDALONE_DEST)/%:
	mkdir -p $@

ifneq ($(INCLUDE_METAL_SOURCES),)

standalone: \
		$(STANDALONE_DEST) \
		$(STANDALONE_DEST)/bsp \
		$(STANDALONE_DEST)/src \
		$(SRC_DIR) \
		freedom-metal \
		debug.mk \
		release.mk \
		scripts/standalone.mk \
		scripts/libmetal.mk
	cp -r $(addprefix $(BSP_DIR)/,$(filter-out build,$(shell ls $(BSP_DIR)))) $</bsp/

	cp -r freedom-metal $</

	find $</freedom-metal -name ".git*" | xargs rm

	$(MAKE) -C $(SRC_DIR) clean
	cp -r $(SRC_DIR)/* $</src/

	cp debug.mk $</debug.mk
	cp release.mk $</release.mk

	echo "PROGRAM = $(PROGRAM)" > $</Makefile
	cat scripts/standalone.mk >> $</Makefile
	cat scripts/libmetal.mk >> $</Makefile

else
standalone: \
		$(STANDALONE_DEST) \
		$(STANDALONE_DEST)/bsp \
		$(STANDALONE_DEST)/src \
		$(BSP_DIR)/install/lib/libmetal.a \
		$(BSP_DIR)/install/lib/libmetal-gloss.a \
		$(SRC_DIR) \
		debug.mk \
		release.mk \
		scripts/standalone.mk
	cp -r $(addprefix $(BSP_DIR)/,$(filter-out build,$(shell ls $(BSP_DIR)))) $</bsp/

	$(MAKE) -C $(SRC_DIR) clean
	cp -r $(SRC_DIR)/* $</src/

	cp debug.mk $</debug.mk
	cp release.mk $</release.mk

	echo "PROGRAM = $(PROGRAM)" > $</Makefile
	cat scripts/standalone.mk >> $</Makefile
endif
endif

#############################################################
# CoreIP RTL Simulation Hex File Creation
#############################################################

# Use elf2hex if we're not using Segger J-Link OB (i.e. for coreip-rtl targets)
ifeq ($(SEGGER_JLINK_OB),)
$(PROGRAM_HEX): \
		scripts/elf2hex/install/bin/$(CROSS_COMPILE)-elf2hex \
		$(PROGRAM_ELF)
	$< --output $@ --input $(PROGRAM_ELF) --bit-width $(COREIP_MEM_WIDTH)
endif

#############################################################
# Upload and Debug
#############################################################

ifneq ($(RISCV_OPENOCD_PATH),)
RISCV_OPENOCD=$(RISCV_OPENOCD_PATH)/bin/openocd
else
#if RISCV_OPENOCD_PATH is not set, just look on the PATH
RISCV_OPENOCD=openocd
endif

ifneq ($(SEGGER_JLINK_OB),)
upload: $(PROGRAM_HEX)
	scripts/upload --hex $(PROGRAM_HEX) --jlink $(SEGGER_JLINK_EXE)
else
upload: $(PROGRAM_ELF)
	scripts/upload --elf $(PROGRAM_ELF) --openocd $(RISCV_OPENOCD) --gdb $(RISCV_GDB) --openocd-config bsp/$(TARGET)/openocd.cfg
endif

ifneq ($(SEGGER_JLINK_OB),)
debug: $(PROGRAM_ELF)
	scripts/debug --elf $(PROGRAM_ELF) --jlink $(SEGGER_JLINK_GDB_SERVER) --gdb $(RISCV_GDB)
else
debug: $(PROGRAM_ELF)
	scripts/debug --elf $(PROGRAM_ELF) --openocd $(RISCV_OPENOCD) --gdb $(RISCV_GDB) --openocd-config bsp/$(TARGET)/openocd.cfg
endif

