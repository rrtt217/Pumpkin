#!/bin/bash
# Strip the cross-built ARMv6 binary with the cross binutils and put it in dist/.
#
# Usage: build/strip-armv6.sh [input] [output]
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
X=${ARMV6_XTOOL_ROOT:-$HERE/.armv6-toolchain}
in=${1:-$HERE/target/arm-unknown-linux-gnueabihf/release/pumpkin}
out=${2:-$HERE/dist/pumpkin-armv6}

[ -f "$in" ] || { echo "no binary at $in" >&2; exit 1; }
mkdir -p "$(dirname "$out")"
LD_LIBRARY_PATH="$X/xgcc/usr/lib/x86_64-linux-gnu:$X/hostlibs/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$X/xgcc/usr/bin/arm-linux-gnueabihf-strip" --strip-unneeded -o "$out" "$in"
echo "wrote $out ($(du -h "$out" | cut -f1))"
