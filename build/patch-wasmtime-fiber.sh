#!/bin/bash
# Apply the ARMv6 fix to wasmtime-internal-fiber in the cargo registry cache.
#
# The crate's 32-bit ARM stack-switch asm uses `blx` without declaring the
# target architecture. rustc 1.95 happens to accept it, but newer stables
# reject it with "instruction requires: armv5t" because the integrated
# assembler starts from an ARMv4T baseline. Inserting `.arch armv6` at the top
# of both blocks fixes that on every compiler that still supports ARMv6.
#
# The patch is applied to the source cargo already unpacked, so the repository
# carries no vendored copy and Cargo.lock stays untouched. Run `cargo fetch`
# first (build-pumpkin.sh does).
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
CARGO_HOME=${CARGO_HOME:-$HOME/.cargo}

version=$(python3 - "$HERE/Cargo.lock" <<'EOF'
import re, sys
lock = open(sys.argv[1]).read()
m = re.search(r'name = "wasmtime-internal-fiber"\nversion = "([^"]+)"', lock)
print(m.group(1) if m else "")
EOF
)
[ -n "$version" ] || { echo "wasmtime-internal-fiber not found in Cargo.lock" >&2; exit 1; }

shopt -s nullglob
dirs=("$CARGO_HOME"/registry/src/*/wasmtime-internal-fiber-"$version")
shopt -u nullglob
[ ${#dirs[@]} -gt 0 ] || {
  echo "wasmtime-internal-fiber-$version is not in $CARGO_HOME/registry/src; run cargo fetch first" >&2
  exit 1
}

for dir in "${dirs[@]}"; do
  python3 - "$dir/src/stackswitch/arm.rs" <<'EOF'
import sys

path = sys.argv[1]
src = open(path).read()
if ".arch armv6" in src:
    print(f"{path}: already patched")
    sys.exit(0)

lines = src.splitlines(keepends=True)
out = []
patched = 0
i = 0
while i < len(lines):
    out.append(lines[i])
    if lines[i].strip() == "naked_asm!(" and i + 1 < len(lines) and lines[i + 1].strip() == '"':
        out.append(lines[i + 1])
        out.append("        .arch armv6\n")
        i += 2
        patched += 1
        continue
    i += 1
if not patched:
    sys.exit(f"{path}: no naked_asm! blocks found, the patch does not apply")
open(path, "w").write("".join(out))
print(f"{path}: patched {patched} block(s)")
EOF
done
