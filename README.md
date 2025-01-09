# Mainly for debugging kernel builds 

This is a makefile for easying the building of linux kernel + buildroot and initramfs. 
Probably there is an easier way... 

See below


# Linux Build System

## Quick Start

```bash
# Clone the repository
git clone https://github.com/latedeployment/kernelkernel.git
cd kernelkernel

# Build everything
make

# Run in QEMU
make run
```

## Prerequisites

### Required Packages

- Linux build tools (gcc, make, etc.)
- QEMU for system emulation
- ncurses development libraries (for menuconfig)
- Cross-compilation toolchain

On Debian/Ubuntu systems:
```bash
sudo apt-get install build-essential qemu-system-x86 libncurses-dev
```

### Basic Build Commands

```bash
# Build everything with default settings
make

# Build with specific number of jobs
make JOBS=4              # Use 4 parallel jobs
make JOBS=1              # Sequential build
make                     # Use predefined number of cores (default)

# View current build configuration
make config-info
```

### Configuration Commands

```bash
# Configure the kernel
make kernel-menuconfig

# Configure buildroot
make buildroot-config
```

### Run Commands

```bash
# Run in QEMU (without KVM)
make run

# Run in QEMU with KVM enabled (faster)
make run-kvm
```

> Exit QEMU by pressing: `Ctrl-a x`

### Cleaning Commands

```bash
# Clean build artifacts (preserve config)
make clean

# Complete clean (remove all files and configs)
make mrproper
```

### Debugging
```
For debugging:
  1. Run 'make debug' or 'make debug-kvm' in one terminal
  2. In another terminal:
     gdb /home/$(HOME)/src/linux-dev/builds/linux/vmlinux
     (gdb) target remote localhost:1234
     (gdb) b start_kernel
     (gdb) c
```
