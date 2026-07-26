#!/usr/bin/env bash
#
# Build an installable .qpkg for a given QNAP architecture.
#
# Usage: scripts/build-qnap-qpkg.sh <qdk-arch>
#   e.g. scripts/build-qnap-qpkg.sh arm-x19
#        scripts/build-qnap-qpkg.sh x86_64
#
# Steps:
#   1. build the static binary for <qdk-arch> (scripts/build-qnap-binary.sh)
#   2. stage it into package/qnap/<qdk-arch>/
#   3. run QNAP's qbuild (QDK) to produce the .qpkg for that arch
#
# QDK only runs on Linux. If `qbuild` is on PATH it is used directly; otherwise
# the script falls back to a local Docker image ("qdk-builder") built from
# scripts/qdk.Dockerfile. Docker is used for the BUILD ONLY; nothing is
# installed on or required by the NAS.
#
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$(pwd)"
# shellcheck source=scripts/qnap-arches.sh
. scripts/qnap-arches.sh

ARCH="${1:?usage: build-qnap-qpkg.sh <qdk-arch>}"
qnap_arch_to_go "$ARCH" >/dev/null  # validate arch

VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo 0.0.0)}"
CLEAN_VERSION="${VERSION#v}"
PKG_DIR="package/qnap"
BIN="dist/ps3netsrv-go-qnap-${ARCH}"

# 1. build binary if missing
if [ ! -f "$BIN" ]; then
    VERSION="$VERSION" ./scripts/build-qnap-binary.sh "$ARCH"
fi

# 2. stage the package into a throwaway build dir under dist/ so qbuild (which
#    rewrites qpkg.cfg with the version) never mutates the tracked source tree.
mkdir -p dist
STAGE="dist/qpkg-stage-${ARCH}"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$PKG_DIR"/. "$STAGE"/
mkdir -p "$STAGE/${ARCH}"
cp "$BIN" "$STAGE/${ARCH}/ps3netsrv-go"
chmod +x "$STAGE/${ARCH}/ps3netsrv-go"

# CHD-enabled arch: bundle libchdr.so next to the binary. The service script
# adds the install dir to LD_LIBRARY_PATH so purego dlopen's it at runtime.
if [ -n "$(qnap_arch_chd_target "$ARCH")" ]; then
    LIBCHDR="dist/libchdr-${ARCH}.so"
    [ -f "$LIBCHDR" ] || ./scripts/build-libchdr.sh "$ARCH"
    cp "$LIBCHDR" "$STAGE/${ARCH}/libchdr.so"
    chmod +x "$STAGE/${ARCH}/libchdr.so"
fi

# 3. run qbuild (native if available, else Docker build-only)
if command -v qbuild >/dev/null 2>&1; then
    echo ">> building .qpkg with native qbuild (arch=${ARCH}) ..."
    qbuild --root "$STAGE" --build-arch "$ARCH" --exclude '.gitkeep' \
           --build-version "$CLEAN_VERSION" --build-dir "${REPO}/dist"
else
    echo ">> native qbuild not found; building via Docker (qdk-builder), arch=${ARCH} ..."
    if ! docker image inspect qdk-builder >/dev/null 2>&1; then
        docker build -t qdk-builder -f scripts/qdk.Dockerfile scripts
    fi
    docker run --rm -v "${REPO}:/build" -w /build qdk-builder bash -lc "
        export PATH=/usr/share/QDK/bin:\$PATH
        qbuild --root '${STAGE}' --build-arch '${ARCH}' --exclude '.gitkeep' \
               --build-version '${CLEAN_VERSION}' --build-dir /build/dist
    "
fi
rm -rf "$STAGE"

echo
echo ">> Done. Resulting package(s):"
ls -la dist/*"${ARCH}".qpkg 2>/dev/null || echo "   (no .qpkg found — check qbuild output above)"
