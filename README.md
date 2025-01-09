# Mainly for debugging kernel builds 

This is a makefile for easying the building of linux kernel + buildroot and initramfs. 
Probably there is an easier way... 

See below


# Mini Linux Build System
A streamlined build system for creating minimal Linux distributions using Buildroot, the Linux kernel, and BusyBox. Designed for fast iteration and easy customization, this project automates the entire build process for a minimal Linux system that runs in QEMU.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/latedeployment/kernelkernel.git
cd kernelkernel

# Build everything
make

# Run in QEMU
make run
```

## 📋 Prerequisites

### Required Packages

- Linux build tools (gcc, make, etc.)
- QEMU for system emulation
- ncurses development libraries (for menuconfig)
- Cross-compilation toolchain

On Debian/Ubuntu systems:
```bash
sudo apt-get install build-essential qemu-system-x86 libncurses-dev
```

### External Components

The following components should be present in your project directory:

- Linux kernel source (`linux/`)
- Buildroot source (`buildroot/`)
- BusyBox source (`busybox-1.36.1/`)

### Toolchain Requirements

A cross-compilation toolchain is required with the following specifications:
- Location: `/opt/toolchains/x86_64-unknown-linux-gnu`
- Prefix: `x86_64-unknown-linux-gnu-`
- GCC version: 5.x
- Kernel headers: 4.3.x series
- C library: glibc
- C++ support: enabled

> 💡 You can adjust these settings in the Makefile if your toolchain differs.

## 📁 Directory Structure

```
.
├── builds/               # Build output directory
│   ├── linux/           # Linux kernel build
│   ├── busybox/         # BusyBox build
│   ├── buildroot/       # Buildroot build
│   ├── initramfs/       # Initial RAM filesystem
│   └── toolchains/      # Toolchain build (if building locally)
├── downloads/           # Downloaded source files
├── linux/               # Linux kernel source
├── buildroot/           # Buildroot source
└── busybox-1.36.1/     # BusyBox source
```

## 🛠️ Usage

### Basic Build Commands

```bash
# Build everything with default settings
make

# Build with specific number of jobs
make JOBS=4              # Use 4 parallel jobs
make JOBS=1              # Sequential build
make                     # Use all CPU cores (default)

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

> 💡 Exit QEMU by pressing: `Ctrl-a x`

### Cleaning Commands

```bash
# Clean build artifacts (preserve config)
make clean

# Complete clean (remove all files and configs)
make mrproper
```

## 🎯 Build Targets

| Target | Description |
|--------|-------------|
| `all` | Build everything (default target) |
| `kernel-init` | Initialize kernel configuration |
| `kernel-menuconfig` | Configure the kernel |
| `kernel-build` | Build the kernel and modules |
| `buildroot-init` | Initialize buildroot |
| `buildroot-config` | Configure buildroot |
| `buildroot-build` | Build root filesystem |
| `initramfs` | Create initial RAM filesystem |
| `run` | Run in QEMU |
| `run-kvm` | Run in QEMU with KVM |
| `clean` | Clean build artifacts |
| `mrproper` | Deep clean |
| `config-info` | Show build configuration |


