#!/usr/bin/env bash
#
# Build libchdr.so for a CHD-enabled QNAP architecture.
#
# Usage: scripts/build-libchdr.sh <qdk-arch>   (e.g. x86_64, arm_64)
#
# CHD support in ps3netsrv-go is provided by purego dlopen'ing an external
# libchdr.so at runtime. This builds that library (rtissera/libchdr v0.3.0, the
# version whose API the purego binding targets) as a plain shared object with a
# standard GNU toolchain. Modern QTS/QuTS glibc loads it directly; no ELF tricks
# needed. Non-CHD arches are a no-op.
#
# The build runs in a throwaway Ubuntu container (host toolchains vary); nothing
# is installed on the host or the NAS. Output: dist/libchdr-<arch>.so
#
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/qnap-arches.sh
. scripts/qnap-arches.sh

ARCH="${1:?usage: build-libchdr.sh <qdk-arch>}"
CHDTGT="$(qnap_arch_chd_target "$ARCH")"
if [ -z "$CHDTGT" ]; then
    echo "libchdr: arch '$ARCH' is not CHD-enabled; nothing to build."
    exit 0
fi

LIBCHDR_REF="${LIBCHDR_REF:-v0.3.0}"
mkdir -p dist
OUT="dist/libchdr-${ARCH}.so"

echo ">> building libchdr ($LIBCHDR_REF) for $ARCH (target=$CHDTGT) ..."
docker run --rm --platform linux/amd64 -v "$(pwd)/dist:/out" ubuntu:24.04 bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null
case '$CHDTGT' in
  x86_64)  apt-get install -y -qq --no-install-recommends cmake make gcc libc6-dev git ca-certificates >/dev/null
           CC=gcc; EXTRA='' ;;
  aarch64) apt-get install -y -qq --no-install-recommends cmake make gcc-aarch64-linux-gnu libc6-dev-arm64-cross git ca-certificates >/dev/null
           CC=aarch64-linux-gnu-gcc
           EXTRA='-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64' ;;
  *) echo 'unknown CHD target $CHDTGT'; exit 1 ;;
esac
git clone --depth 1 --branch '$LIBCHDR_REF' https://github.com/rtissera/libchdr /tmp/libchdr >/dev/null 2>&1
cd /tmp/libchdr
cmake -S . -B build \
  -DCMAKE_C_COMPILER=\"\$CC\" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SHARED_LINKER_FLAGS=-static-libgcc \
  \$EXTRA >/dev/null
cmake --build build --target chdr -j\"\$(nproc)\" >/dev/null 2>&1
SO=\$(find build -name 'libchdr.so.0.3' -type f | head -1)
cp \"\$SO\" '/out/libchdr-${ARCH}.so'
"
echo ">> $OUT"
