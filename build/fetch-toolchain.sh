#!/bin/bash
# Download and unpack the ARMv6 (Raspberry Pi Zero / Pi 1) cross toolchain.
#
# Nothing is installed system-wide: the Debian trixie gcc-14 cross driver, the
# host libraries it links against and the Raspberry Pi OS trixie armhf sysroot
# are all unpacked under $ARMV6_XTOOL_ROOT.
#
# Debian's own armhf sysroot is ARMv7/VFPv3 (it would tag the binary as v7 and
# fault on ARM1176), so the sysroot comes from Raspberry Pi OS instead, which is
# rebuilt for ARMv6 and is trixie-based (glibc 2.41).
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
X=${ARMV6_XTOOL_ROOT:-$HERE/.armv6-toolchain}
CACHE=${ARMV6_DEB_CACHE:-$X/debs}

DEBIAN=http://deb.debian.org/debian
RASPBIAN=http://raspbian.raspberrypi.org/raspbian

# dest|base|pool path|sha256
MANIFEST=$(cat <<'EOF'
xgcc|debian|pool/main/g/gcc-14-cross/gcc-14-arm-linux-gnueabihf_14.2.0-19cross1_amd64.deb|2caeee6eee62b44503939ba93fc75ade0f018e839cfc3207a5e2350864c2d147
xgcc|debian|pool/main/g/gcc-14-cross/cpp-14-arm-linux-gnueabihf_14.2.0-19cross1_amd64.deb|e503180c7e7bb8451b33acd124872c7a43f45903913e8c96467e5ed386f7e434
xgcc|debian|pool/main/b/binutils/binutils-arm-linux-gnueabihf_2.44-3_amd64.deb|9733b7a7a320da0ca637d71e69ab663c64f550ad542a848e5755c8170c8caf09
hostlibs|debian|pool/main/b/binutils/libsframe1_2.44-3_amd64.deb|38f625dfdc582717029ac3a3e97c51d994ec2e7a0e9b230c6b44e40d1276311f
hostlibs|debian|pool/main/b/binutils/libctf0_2.44-3_amd64.deb|120cafcd93132a276fa92a8fb4cf39b23d14e5a3e348f4f5580638d71ca95ac5
hostlibs|debian|pool/main/i/isl/libisl23_0.27-1_amd64.deb|ac8518042e81c00de1effb72bba7e88ac4ecd488f7ea8b9e3ebc63159cb53b35
sysroot|raspbian|pool/main/g/gcc-14/gcc-14-base_14.2.0-19+rpi1_armhf.deb|3a8c5a06b6eb16ec97db57a51f9f32c61862c7a2983ef1ab61b2513f9bedc0f2
sysroot|raspbian|pool/main/g/gcc-14/libatomic1_14.2.0-19+rpi1_armhf.deb|c3911e5833e3602c0dc65272408219bc4c17b62191dcae1b9d97a2c7d24b6351
sysroot|raspbian|pool/main/g/gcc-14/libgomp1_14.2.0-19+rpi1_armhf.deb|39478976bf4c2e57486ed8e36ab000c69190c24f16b56d5ba252a6213cf2d53e
sysroot|raspbian|pool/main/g/glibc/libc6_2.41-12+rpi1+deb13u2_armhf.deb|436b0fb93c80dded5ace51fbbc487b8a0b59a08d7bad9e914038cd7e4ec9a68b
sysroot|raspbian|pool/main/g/glibc/libc6-dev_2.41-12+rpi1+deb13u2_armhf.deb|592f76e44e983e76489a29ac60b6c7cda9a4ae1e94f9df446efb8a31154293e2
sysroot|raspbian|pool/main/g/gcc-14/libgcc-s1_14.2.0-19+rpi1_armhf.deb|f7526cd48780b10cf71df12b086a38ab542e68f6faa6345480b019bbc6b7c461
sysroot|raspbian|pool/main/g/gcc-14/libgcc-14-dev_14.2.0-19+rpi1_armhf.deb|02552a49f7c754961de873133d6d2ec40a6ee3cb7205e37b3751019face9af3b
sysroot|raspbian|pool/main/g/gcc-14/libstdc++6_14.2.0-19+rpi1_armhf.deb|141779d94dc21a0ac8d3d64ac15387e48a58f2dcdba4f55aff7a134982c56ecc
sysroot|raspbian|pool/main/l/linux/linux-libc-dev_6.12.41-1+rpi1_all.deb|872c0123f0ac793183d98e8f7dc4092c483296eca8a6ae62b580553b8c82c5a2
EOF
)

fetch() {
  local url=$1 want=$2 dest=$3
  if [ -f "$dest" ] && echo "$want  $dest" | sha256sum -c --status; then
    return 0
  fi
  echo "downloading $(basename "$dest")"
  curl -fsSL --retry 3 --retry-delay 2 -o "$dest.part" "$url"
  mv "$dest.part" "$dest"
  if ! echo "$want  $dest" | sha256sum -c --status; then
    echo "checksum mismatch for $url" >&2
    rm -f "$dest"
    exit 1
  fi
}

mkdir -p "$CACHE" "$X"
while IFS='|' read -r dest base path sha; do
  [ -n "$dest" ] || continue
  case "$base" in
    debian) root=$DEBIAN ;;
    raspbian) root=$RASPBIAN ;;
    *) echo "unknown mirror: $base" >&2; exit 1 ;;
  esac
  fetch "$root/$path" "$sha" "$CACHE/$(basename "$path")"
done <<< "$MANIFEST"

for dir in xgcc hostlibs sysroot; do
  rm -rf "$X/$dir"
  mkdir -p "$X/$dir"
done
while IFS='|' read -r dest base path sha; do
  [ -n "$dest" ] || continue
  dpkg-deb -x "$CACHE/$(basename "$path")" "$X/$dest"
done <<< "$MANIFEST"

# dpkg-deb does not create the merged-/usr layout the armhf loader paths expect
[ -e "$X/sysroot/lib" ] || ln -s usr/lib "$X/sysroot/lib"
[ -e "$X/sysroot/usr/lib/ld-linux-armhf.so.3" ] ||
  ln -s arm-linux-gnueabihf/ld-linux-armhf.so.3 "$X/sysroot/usr/lib/ld-linux-armhf.so.3"

# guard against a v7 sysroot slipping in again
attrs=$(readelf -A "$X/sysroot/usr/lib/arm-linux-gnueabihf/Scrt1.o")
if ! grep -q 'Tag_CPU_arch: v6' <<< "$attrs"; then
  echo "sysroot Scrt1.o is not ARMv6:" >&2
  echo "$attrs" >&2
  exit 1
fi

echo "toolchain ready in $X"
