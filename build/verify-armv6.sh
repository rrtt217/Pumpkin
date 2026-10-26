#!/bin/bash
# Boot an ARMv6 build under qemu -cpu arm1176, answer a Java status ping and
# check that SIGTERM shuts the server down cleanly.
#
# -cpu arm1176 faults on any ARMv7 instruction, so a passing run also proves the
# binary does not execute v7/NEON code on the hot paths we touch.
#
# Usage: build/verify-armv6.sh [binary]   (needs qemu-arm or qemu-arm-static)
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
X=${ARMV6_XTOOL_ROOT:-$HERE/.armv6-toolchain}
bin=${1:-$HERE/dist/pumpkin-armv6}
qemu=${QEMU_ARM:-$(command -v qemu-arm-static || command -v qemu-arm || true)}

[ -f "$bin" ] || { echo "no binary at $bin" >&2; exit 1; }
bin=$(cd "$(dirname "$bin")" && pwd)/$(basename "$bin")
[ -n "$qemu" ] || { echo "qemu-arm/qemu-arm-static not found" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

"$qemu" -cpu arm1176 -L "$X/sysroot" "$bin" > server.log 2>&1 &
pid=$!

for _ in $(seq 1 180); do
  grep -q 'Server is now running' server.log 2>/dev/null && break
  kill -0 "$pid" 2>/dev/null || { echo "server exited before listening" >&2; cat server.log; exit 1; }
  sleep 1
done
grep -q 'Server is now running' server.log || { echo "server did not start" >&2; cat server.log; exit 1; }

python3 "$HERE/build/status-ping.py"

kill -TERM "$pid"
wait "$pid" || true
grep -q 'The server has stopped' server.log || { echo "server did not stop cleanly" >&2; cat server.log; exit 1; }
grep -q 'Completed save' server.log || { echo "world was not saved on shutdown" >&2; cat server.log; exit 1; }

echo "armv6 verification ok"
