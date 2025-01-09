SHELL := /bin/bash

# Parallel jobs configuration
PARALLEL := -j 8

# Versions
BUSYBOX_VERSION ?= 1.36.1

# Base directories
LINUX_BUILD_DEV_BASE := $(shell pwd)
BUILDS := $(LINUX_BUILD_DEV_BASE)/builds
DOWNLOADS := $(LINUX_BUILD_DEV_BASE)/downloads

# Build directories
LINUX_BUILD := $(BUILDS)/linux
BUSYBOX_BUILD := $(BUILDS)/busybox
INITRAMFS_BUILD := $(BUILDS)/initramfs
BUILDROOT_BUILD := $(BUILDS)/buildroot
TOOLCHAINS_BUILD := $(BUILDS)/toolchains

# Source directories and versions
BUSYBOX := $(LINUX_BUILD_DEV_BASE)/busybox-$(BUSYBOX_VERSION)
BUILDROOT := $(LINUX_BUILD_DEV_BASE)/buildroot
LINUX := $(LINUX_BUILD_DEV_BASE)/linux

# Download URLs
BUSYBOX_URL := https://www.busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2

# Toolchain settings
TOOLCHAIN_PATH := /opt/toolchains/x86_64-unknown-linux-gnu
CROSS_COMPILE := $(TOOLCHAIN_PATH)/bin/x86_64-unknown-linux-gnu-

# Create all necessary directories
$(BUILDS) $(DOWNLOADS) $(LINUX_BUILD) $(BUSYBOX_BUILD) $(INITRAMFS_BUILD) $(BUILDROOT_BUILD) $(TOOLCHAINS_BUILD):
	mkdir -p $@

.PHONY: all clean mrproper buildroot-init buildroot-config buildroot-build initramfs kernel menuconfig busybox-init busybox-menuconfig busybox-build download-busybox

all: buildroot-build kernel

# Download and extract BusyBox
download-busybox: | $(DOWNLOADS)
	test -d $(BUSYBOX) || ( \
		wget -P $(DOWNLOADS) $(BUSYBOX_URL) && \
		tar -xf $(DOWNLOADS)/busybox-$(BUSYBOX_VERSION).tar.bz2 -C $(LINUX_BUILD_DEV_BASE) \
	)

# Main kernel targets
kernel: $(LINUX_BUILD)/arch/x86_64/boot/bzImage

menuconfig: | $(LINUX_BUILD)
	test -f $(LINUX_BUILD)/.config || (cd $(LINUX) && make O=$(LINUX_BUILD) allnoconfig)
	cd $(LINUX_BUILD) && make menuconfig

# The actual kernel binary target and its dependencies
$(LINUX_BUILD)/arch/x86_64/boot/bzImage: $(LINUX_BUILD)/.config
	cd $(LINUX_BUILD) && make $(PARALLEL) all
	cd $(LINUX_BUILD) && make $(PARALLEL) modules
	cd $(LINUX_BUILD) && make modules_install INSTALL_MOD_PATH=$(BUILDROOT_BUILD)/overlay

# Kernel config file target
$(LINUX_BUILD)/.config: | $(LINUX_BUILD)
	cd $(LINUX) && make O=$(LINUX_BUILD) allnoconfig

# Busybox targets
busybox-init: download-busybox | $(BUSYBOX_BUILD)
	test -f $(BUSYBOX_BUILD)/.config || (cd $(BUSYBOX) && make O=$(BUSYBOX_BUILD) defconfig)

busybox-menuconfig: busybox-init
	cd $(BUSYBOX_BUILD) && make menuconfig

busybox-build: busybox-init
	cd $(BUSYBOX_BUILD) && make $(PARALLEL)
	cd $(BUSYBOX_BUILD) && make install

# Initialize buildroot configuration
buildroot-init: | $(BUILDROOT_BUILD)
	test -f $(BUILDROOT_BUILD)/.config || (cd $(BUILDROOT_BUILD) && touch Config.in external.mk \
		&& echo 'name: mini_linux' > external.desc \
		&& echo 'desc: minimal linux system with buildroot' >> external.desc \
		&& mkdir -p configs overlay \
		&& cd $(BUILDROOT) && make O=$(BUILDROOT_BUILD) BR2_EXTERNAL=$(BUILDROOT_BUILD) qemu_x86_64_defconfig)

# Configure buildroot (runs menuconfig)
buildroot-config: buildroot-init
	cd $(BUILDROOT_BUILD) && make menuconfig
	cd $(BUILDROOT_BUILD) && make savedefconfig

# Build buildroot with root filesystem
buildroot-build: | $(BUILDROOT_BUILD)
	cd $(BUILDROOT_BUILD) && make $(PARALLEL)

# Create simple initramfs
initramfs: busybox-build | $(INITRAMFS_BUILD)
	mkdir -p $(INITRAMFS_BUILD)/{bin,sbin,etc,proc,sys,usr/{bin,sbin}}
	cp -a $(BUSYBOX_BUILD)/_install/* $(INITRAMFS_BUILD)/
	echo '#!/bin/sh' > $(INITRAMFS_BUILD)/init
	echo 'mount -t proc none /proc' >> $(INITRAMFS_BUILD)/init
	echo 'mount -t sysfs none /sys' >> $(INITRAMFS_BUILD)/init
	echo 'echo "Boot complete"' >> $(INITRAMFS_BUILD)/init
	echo 'exec /bin/sh' >> $(INITRAMFS_BUILD)/init
	chmod +x $(INITRAMFS_BUILD)/init
	cd $(INITRAMFS_BUILD) && find . -print0 | cpio --null -ov --format=newc | gzip -9 > $(BUILDS)/initramfs.cpio.gz

# Cleaning targets
clean:
	-cd $(LINUX_BUILD) && make clean
	-cd $(BUILDROOT_BUILD) && make clean
	-cd $(BUSYBOX_BUILD) && make clean
	rm -rf $(INITRAMFS_BUILD)/*

mrproper:
	-cd $(LINUX_BUILD) && make mrproper
	-cd $(BUILDROOT_BUILD) && make distclean
	-cd $(BUSYBOX_BUILD) && make distclean
	rm -rf $(BUILDS)/*
	rm -rf $(DOWNLOADS)/*

# Run QEMU
.PHONY: run
run: kernel initramfs
	qemu-system-x86_64 -kernel $(LINUX_BUILD)/arch/x86_64/boot/bzImage \
		-initrd $(BUILDS)/initramfs.cpio.gz -nographic \
		-append "console=ttyS0"

# Run QEMU with KVM enabled
.PHONY: run-kvm
run-kvm: kernel initramfs
	qemu-system-x86_64 -kernel $(LINUX_BUILD)/arch/x86_64/boot/bzImage \
		-initrd $(BUILDS)/initramfs.cpio.gz -nographic \
		-append "console=ttyS0" -enable-kvm

# Run QEMU with GDB debugging enabled
.PHONY: debug
debug: kernel initramfs
	@echo "Starting QEMU with GDB server on tcp::1234"
	@echo "To connect with GDB, run: gdb $(LINUX_BUILD)/vmlinux"
	@echo "At the GDB prompt, type: target remote localhost:1234"
	qemu-system-x86_64 -kernel $(LINUX_BUILD)/arch/x86_64/boot/bzImage \
		-initrd $(BUILDS)/initramfs.cpio.gz -nographic \
		-append "console=ttyS0 nokaslr" \
		-s -S

# Run QEMU with KVM and GDB debugging enabled
.PHONY: debug-kvm
debug-kvm: kernel initramfs
	@echo "Starting QEMU with GDB server on tcp::1234"
	@echo "To connect with GDB, run: gdb $(LINUX_BUILD)/vmlinux"
	@echo "At the GDB prompt, type: target remote localhost:1234"
	qemu-system-x86_64 -kernel $(LINUX_BUILD)/arch/x86_64/boot/bzImage \
		-initrd $(BUILDS)/initramfs.cpio.gz -nographic \
		-append "console=ttyS0 nokaslr" \
		-enable-kvm -s -S

# Print configuration
.PHONY: config-info
config-info:
	@echo "Build configuration:"
	@echo "  JOBS:         $(JOBS) (override with make JOBS=N)"
	@echo "  PARALLEL:     $(PARALLEL)"
	@echo "  NPROC:        $(NPROC)"
	@echo "  BUSYBOX_VER:  $(BUSYBOX_VERSION) (override with make BUSYBOX_VERSION=X.Y.Z)"

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo
	@echo "Main targets:"
	@echo "  all              - Build everything (buildroot and kernel)"
	@echo "  clean            - Clean build artifacts"
	@echo "  mrproper         - Deep clean, including downloads"
	@echo
	@echo "Kernel targets:"
	@echo "  kernel           - Build the Linux kernel"
	@echo "  menuconfig       - Configure the kernel"
	@echo
	@echo "BusyBox targets:"
	@echo "  download-busybox - Download and extract BusyBox source"
	@echo "  busybox-init     - Initialize BusyBox configuration"
	@echo "  busybox-menuconfig - Configure BusyBox"
	@echo "  busybox-build    - Build BusyBox"
	@echo
	@echo "Buildroot targets:"
	@echo "  buildroot-init   - Initialize Buildroot"
	@echo "  buildroot-config - Configure Buildroot"
	@echo "  buildroot-build  - Build Buildroot"
	@echo
	@echo "InitRAMFS targets:"
	@echo "  initramfs        - Create initial RAM filesystem"
	@echo
	@echo "Run targets:"
	@echo "  run              - Run in QEMU"
	@echo "  run-kvm          - Run in QEMU with KVM acceleration"
	@echo "  debug            - Run in QEMU with GDB server enabled"
	@echo "  debug-kvm        - Run in QEMU with KVM and GDB server"
	@echo
	@echo "Information:"
	@echo "  config-info      - Show build configuration"
	@echo "  help             - Show this help message"
	@echo
	@echo "Environment variables:"
	@echo "  BUSYBOX_VERSION  - BusyBox version to use (default: $(BUSYBOX_VERSION))"
	@echo "  PARALLEL         - Parallel jobs for make (default: $(PARALLEL))"
	@echo
	@echo "For debugging:"
	@echo "  1. Run 'make debug' or 'make debug-kvm' in one terminal"
	@echo "  2. In another terminal:"
	@echo "     $ gdb $(LINUX_BUILD)/vmlinux"
	@echo "     (gdb) target remote localhost:1234"
	@echo "     (gdb) b start_kernel"
	@echo "     (gdb) c"