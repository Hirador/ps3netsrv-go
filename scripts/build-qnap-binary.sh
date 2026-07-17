#!/usr/bin/env bash
#
# Build a fully static ps3netsrv-go binary for a given QNAP architecture.
#
# Usage: scripts/build-qnap-binary.sh <qdk-arch>
#   e.g. scripts/build-qnap-binary.sh arm-x19
#
# The build is CGO-free and statically linked (-tags nopurego) so it runs on
# any QTS/libc variant without dynamic-loader or glibc-symbol issues. This
# drops optional CHD support (which needs an external libchdr.so); ISO/CSO/ZSO/
# PKG streaming is unaffected.
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

echo "Building ps3netsrv-go  arch=${ARCH}  GOARCH=${GOARCH} GOARM=${GOARM:-n/a}  version=${VERSION}"

CGO_ENABLED=0 GOOS=linux GOARCH="$GOARCH" GOARM="${GOARM}" \
  go build \
    -tags nopurego \
    -trimpath \
    -ldflags "-w -s -X 'main.Version=${VERSION}'" \
    -o "${OUT}" \
    ./cmd/ps3netsrv-go

if command -v file >/dev/null 2>&1; then
  file "${OUT}"
fi
