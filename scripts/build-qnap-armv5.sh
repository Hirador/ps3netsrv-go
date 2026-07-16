#!/usr/bin/env bash
#
# Build a fully static ps3netsrv-go binary for legacy QNAP NAS units based on
# the Marvell Kirkwood ARMv5 SoC (TS-119/TS-219/TS-419/TS-x12 class, "armv5tel",
# QTS 4.x, uClibc).
#
# Why a special build is needed:
#   * The stock/third-party QPKG is compiled with cgo and fails at load with
#     "undefined symbol: pthread_attr_getstacksize" on the NAS's old libc.
#   * The upstream `linux/arm` release uses the default GOARM=7, which emits
#     instructions the ARMv5 CPU does not implement.
#   * purego dynamically links against libc (interpreter /lib/ld-linux.so.3),
#     which is not present as glibc on the uClibc-based NAS.
#
# This script produces a binary that is:
#   * CGO_ENABLED=0   -> no libc symbol dependencies
#   * GOARM=5         -> valid ARMv5 instruction set
#   * -tags nopurego  -> statically linked, no dynamic interpreter
#     (drops optional CHD support, which would need an external libchdr.so
#      that is impractical to provide on this platform)
#
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo dev)}"
OUT="${OUT:-dist/ps3netsrv-go-qnap-armv5}"

mkdir -p "$(dirname "$OUT")"

echo "Building ps3netsrv-go for QNAP ARMv5 (uClibc, static) ..."
echo "  version = ${VERSION}"
echo "  output  = ${OUT}"

CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 \
  go build \
    -tags nopurego \
    -trimpath \
    -ldflags "-w -s -X 'main.Version=${VERSION}'" \
    -o "${OUT}" \
    ./cmd/ps3netsrv-go

echo
echo "Done. Verify it is statically linked (should say 'statically linked'):"
if command -v file >/dev/null 2>&1; then
  file "${OUT}"
fi
