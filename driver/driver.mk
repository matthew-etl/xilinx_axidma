#-----------------------------------------------------------------------------------------------------------------------
#
# Xilinx DMA Bridge Driver Makefile
#
# Author:			Brandon Perez <bmperez@alumni.cmu.edu>
# Creation Date:	Saturday, March 5, 2016 at 04:46:27 PM EST
#
# Description:
#
#	This is the Makefile used for compiling the Xilinx DMA Bridge driver against the build kernel. This is invoked by
#	the main Makefile. This file exports the relevant variables to the Kbuild file and Linux kernel, and also invokes
#	the Linux kenrel's Makefile to compile the driver. It also performs some basic sanity checking.
#
#-----------------------------------------------------------------------------------------------------------------------

# Include guard for the Makefile.
ifndef DRIVER_MAKEFILE_
DRIVER_MAKEFILE_=included

# Get the user defined variables, if they specified them.
-include config.mk

# Get the library include paths.
include library/library.mk

#-----------------------------------------------------------------------------------------------------------------------
# Configuration
#-----------------------------------------------------------------------------------------------------------------------

# Export user variables for the Kbuild file and kernel Makefile.
ifdef CROSS_COMPILE
    export CROSS_COMPILE
endif
ifdef ARCH
    export ARCH
endif

# When natively compiling, we can infer the kernel's source tree directory, if the user has not specified it.
ifndef CROSS_COMPILE
    KERNEL_VERSION = $(shell uname -r)
    KBUILD_DIR ?= /lib/modules/$(KERNEL_VERSION)/build/
endif

# The kernel symbols file, used for dependency checking to determine if the kernel has been built.
KERNEL_SYMS = $(KBUILD_DIR)/Module.symvers

# The list of source files for the driver. Export the names to the Kbuild file.
DRIVER_DIR = driver
export DRIVER_FILES = xilinx_dma_bridge_main.c axidma_chrdev.c axidma_dma.c axidma.h \
		axidma_of.c
DRIVER_PATHS = $(addprefix $(DRIVER_DIR)/,$(DRIVER_FILES))

# The kernel object files generated by compilation.
export DRIVER_MODULE_NAME = xilinx_dma_bridge
DRIVER_OBJECT = $(DRIVER_DIR)/$(DRIVER_MODULE_NAME).ko
DRIVER_OUTPUT_OBJECT = $(OUTPUT_DIR)/$(DRIVER_MODULE_NAME).ko

# Export the include directories to the Kbuild file, making sure the path is absolute, as the kernel Makefile is run in
# a different directory.
# TODO: Update LIBAXIDMA name to LIBRARY.
export DRIVER_INC_DIRS = $(PWD)/$(LIBAXIDMA_INC_DIRS)

#-----------------------------------------------------------------------------------------------------------------------
# Targets
#-----------------------------------------------------------------------------------------------------------------------

# These targets don't correspond to actual generated files.
.PHONY: driver driver_clean kbuild_def_check arch_def_check kbuild_exists_check kbuild_built_check

# User-facing targets for compiling the driver
driver: $(DRIVER_OUTPUT_OBJECT)

# Compile the driver against the given kernel. The check targets are phony, so don't re-run this target because of them.
$(DRIVER_OBJECT): $(DRIVER_PATHS) $(KERNEL_SYMS) | kbuild_def_check arch_def_check kbuild_exists_check \
			kbuild_built_check cross_compiler_check
	make -C $(KBUILD_DIR) M=$(PWD)/$(DRIVER_DIR) modules

# Copy the compiled driver to the specified output directory
$(DRIVER_OUTPUT_OBJECT): $(DRIVER_OBJECT) $(OUTPUT_DIR)
	@cp $< $@

# Clean up all the files generated by compiling the driver
driver_clean: | kbuild_def_check arch_def_check kbuild_exists_check
	rm -f $(DRIVER_OUTPUT_OBJECT)
	make -C $(KBUILD_DIR) SUBDIRS=$(PWD)/$(DRIVER_DIR) clean

# Check that KBUILD_DIR is explicitly specified when cross-compiling.
kbuild_def_check:
ifndef KBUILD_DIR
	@printf "Error: The variable 'KBUILD_DIR' must be specified when cross-compiling the driver.\n"
	@exit 1
endif

# Check that ARCH is defined when CROSS_COMPILE is specified.
arch_def_check:
ifdef CROSS_COMPILE
ifndef ARCH
	@printf "Error: 'ARCH' must be specified when cross-compiling the driver.\n"
	@exit 1
endif
endif

# Check that the specified kernel source tree directory exists.
kbuild_exists_check:
ifeq (,$(wildcard $(KBUILD_DIR)))
	@printf "Error: $(KBUILD_DIR): The kernel source tree does not exist.\n"
	@exit 1
endif

# Check that the kernel is built in the specified kernel source tree.
kbuild_built_check:
ifeq (,$(wildcard $(KERNEL_SYMS)))
	@printf "Error: $(KBUILD_DIR): This is not a valid kernel build tree or the kernel has not yet been built. The "
	@printf "kernel must be built before compiling the driver against it.\n"
	@exit 1
endif

endif # DRIVER_MAKEFILE_
