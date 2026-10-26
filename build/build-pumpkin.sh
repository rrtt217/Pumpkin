#!/bin/bash
# Build Pumpkin for ARMv6 (Raspberry Pi Zero / Pi 1).
#
# Toolchain files come from build/fetch-toolchain.sh and live under
# $ARMV6_XTOOL_ROOT (default: $repo/.armv6-toolchain). Nothing is installed
# system-wide.
#
# The wrapper build/armv6-pi-gcc adds --sysroot/-B/-march=armv6 and strips
# .ARM.attributes from assembler objects: ring's perlasm emits v7/NEON code that
# is unreachable on ARM1176 but would otherwise tag the ELF as v7.
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
X=${ARMV6_XTOOL_ROOT:-$HERE/.armv6-toolchain}
TARGET=arm-unknown-linux-gnueabihf

# the repo's rust-toolchain.toml asks for components a build does not need
export RUSTUP_TOOLCHAIN=${RUSTUP_TOOLCHAIN:-stable}
export LD_LIBRARY_PATH="$X/xgcc/usr/lib/x86_64-linux-gnu:$X/hostlibs/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

export CC_arm_unknown_linux_gnueabihf="$HERE/build/armv6-pi-gcc"
export CXX_arm_unknown_linux_gnueabihf="$HERE/build/armv6-pi-gcc"
export AR_arm_unknown_linux_gnueabihf="$X/xgcc/usr/bin/arm-linux-gnueabihf-ar"
export CFLAGS_arm_unknown_linux_gnueabihf="-O2"
export CXXFLAGS_arm_unknown_linux_gnueabihf="-O2"
export CARGO_TARGET_ARM_UNKNOWN_LINUX_GNUEABIHF_LINKER="$HERE/build/armv6-pi-gcc"
export CARGO_TARGET_ARM_UNKNOWN_LINUX_GNUEABIHF_RUSTFLAGS="-C target-cpu=arm1176jzf-s"

# LTO off keeps peak memory sane; opt-level stays 3.
export CARGO_PROFILE_RELEASE_LTO=false
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16

cd "$HERE"
cargo fetch --locked --target "$TARGET"
./build/patch-wasmtime-fiber.sh
exec cargo build --locked -p pumpkin --bin pumpkin --target "$TARGET" --release "$@"
