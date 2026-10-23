#!/usr/bin/env bash
#
# Build libchdr.so for a CHD-enabled QNAP architecture.
#
# Usage: scripts/build-libchdr.sh <qdk-arch>   (e.g. x86_64, arm_64, arm-x19)
#
# CHD support in ps3netsrv-go is provided by purego dlopen'ing an external
# libchdr.so at runtime. This builds that library as a plain shared object with
# a standard GNU toolchain, in a throwaway Ubuntu container; nothing is installed
# on the host or the NAS. Output: dist/libchdr-<arch>.so
#
# Targets differ:
#   x86_64 / aarch64  -> rtissera/libchdr v0.3.0, modern glibc, plain -shared.
#                        Modern QTS/QuTS loads it directly; no tricks.
#   arm-softfloat     -> ARMv5TE soft-float for the Kirkwood (no FPU), built from
#                        libchdr master so the -DCHDR_LOWRAM_TARGET=ON option is
#                        available (checkpointed per-hunk map; lighter on the
#                        128-256 MB Kirkwood). It must load on the box's ancient
#                        glibc 2.5: a modern C toolchain redirects sscanf to a
#                        versioned __isocNN_sscanf (GLIBC_2.7 for C99,
#                        GLIBC_2.38 for C23) that glibc 2.5 lacks, so we shim both
#                        to plain vsscanf (GLIBC_2.4). Needs purego >= v0.11.1
#                        (ARM soft-float support) at runtime.
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

mkdir -p dist
OUT="dist/libchdr-${ARCH}.so"

echo ">> building libchdr for $ARCH (target=$CHDTGT) ..."
docker run --rm --platform linux/amd64 -v "$(pwd)/dist:/out" ubuntu:24.04 bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null

REF='v0.3.0'       # libchdr ref to build (overridden per target below)
CFLAGS=''          # extra C flags
EXTRA=''           # extra cmake defines
LINK='-static-libgcc'

case '$CHDTGT' in
  x86_64)  apt-get install -y -qq --no-install-recommends cmake make gcc libc6-dev git ca-certificates >/dev/null
           CC=gcc ;;
  aarch64) apt-get install -y -qq --no-install-recommends cmake make gcc-aarch64-linux-gnu libc6-dev-arm64-cross git ca-certificates >/dev/null
           CC=aarch64-linux-gnu-gcc
           EXTRA='-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64' ;;
  arm-softfloat)
           apt-get install -y -qq --no-install-recommends cmake make gcc-arm-linux-gnueabi libc6-dev-armel-cross binutils-arm-linux-gnueabi git ca-certificates >/dev/null
           CC=arm-linux-gnueabi-gcc
           REF='master'   # CHDR_LOWRAM_TARGET only exists on master
           CFLAGS='-march=armv5te -marm -mfloat-abi=soft'
           EXTRA='-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=arm -DCHDR_LOWRAM_TARGET=ON'
           # sscanf shim: forward the versioned C99/C23 variants to plain vsscanf
           # (GLIBC_2.4) so the lib needs only GLIBC_2.4, loadable on glibc 2.5.
           cat > /tmp/compat.c <<'EOF'
extern int vsscanf(const char *, const char *, __builtin_va_list);
static int _shim(const char *s, const char *f, __builtin_va_list ap){ return vsscanf(s,f,ap); }
int __isoc23_sscanf(const char *s, const char *f, ...){ __builtin_va_list ap; __builtin_va_start(ap,f); int r=_shim(s,f,ap); __builtin_va_end(ap); return r; }
int __isoc99_sscanf(const char *s, const char *f, ...){ __builtin_va_list ap; __builtin_va_start(ap,f); int r=_shim(s,f,ap); __builtin_va_end(ap); return r; }
EOF
           \$CC \$CFLAGS -O2 -fPIC -c /tmp/compat.c -o /tmp/compat.o
           LINK='-static-libgcc /tmp/compat.o' ;;
  *) echo 'unknown CHD target $CHDTGT'; exit 1 ;;
esac

git clone --depth 1 --branch \"\$REF\" https://github.com/rtissera/libchdr /tmp/libchdr >/dev/null 2>&1
cd /tmp/libchdr
cmake -S . -B build \
  -DCMAKE_C_COMPILER=\"\$CC\" \
  -DCMAKE_C_FLAGS=\"\$CFLAGS\" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SHARED_LINKER_FLAGS=\"\$LINK\" \
  \$EXTRA >/dev/null
cmake --build build --target chdr -j\"\$(nproc)\" >/dev/null 2>&1
SO=\$(find build -name 'libchdr.so*' -type f | head -1)
cp \"\$SO\" '/out/libchdr-${ARCH}.so'
"
echo ">> $OUT"
