#!/usr/bin/env bash
#
# Build a fully static ps3netsrv-go binary for a given QNAP architecture.
#
# Usage: scripts/build-qnap-binary.sh <qdk-arch>
#   e.g. scripts/build-qnap-binary.sh arm-x19
#
# CGO-free either way. CHD-enabled arches (see qnap_arch_chd_target) build with
# purego so the server can dlopen a bundled libchdr.so at runtime; the rest build
# fully static (-tags nopurego) so they run on any QTS/libc variant without
# dynamic-loader or glibc-symbol issues (dropping only CHD). ISO/CSO/ZSO/PKG
# streaming is unaffected on all arches.
#
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/qnap-arches.sh
. scripts/qnap-arches.sh

ARCH="${1:?usage: build-qnap-binary.sh <qdk-arch>}"
read -r GOARCH GOARM <<<"$(qnap_arch_to_go "$ARCH")"

VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo dev)}"
OUT="${OUT:-dist/ps3netsrv-go-qnap-${ARCH}}"
mkdir -p "$(dirname "$OUT")"

# CHD-enabled arch -> purego (dynamic, needs libchdr.so); else fully static.
TAGS_ARGS=(-tags nopurego)
BUILDKIND="static (nopurego, no CHD)"
if [ -n "$(qnap_arch_chd_target "$ARCH")" ]; then
    TAGS_ARGS=()
    BUILDKIND="purego (CHD-capable)"
fi

echo "Building ps3netsrv-go  arch=${ARCH}  GOARCH=${GOARCH} GOARM=${GOARM:-n/a}  version=${VERSION}  [${BUILDKIND}]"

CGO_ENABLED=0 GOOS=linux GOARCH="$GOARCH" GOARM="${GOARM}" \
  go build \
    ${TAGS_ARGS[@]+"${TAGS_ARGS[@]}"} \
    -trimpath \
    -ldflags "-w -s -X 'main.Version=${VERSION}'" \
    -o "${OUT}" \
    ./cmd/ps3netsrv-go

if command -v file >/dev/null 2>&1; then
  file "${OUT}"
fi
