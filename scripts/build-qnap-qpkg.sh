#!/usr/bin/env bash
#
# Build an installable .qpkg for legacy ARMv5 (Kirkwood, arm-x19) QNAP NAS.
#
# Steps:
#   1. build the fully static ARMv5 binary (scripts/build-qnap-armv5.sh)
#   2. stage it into package/qnap/arm-x19/
#   3. run QNAP's qbuild (QDK) to produce the .qpkg
#
# QDK only runs on Linux. If you have it installed natively, this script uses
# it directly. Otherwise it falls back to a local Docker image ("qdk-builder")
# built from scripts/qdk.Dockerfile. Docker is used for the BUILD ONLY; nothing
# is installed on the NAS.
#
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$(pwd)"

VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo 0.0.0)}"
CLEAN_VERSION="${VERSION#v}"
PKG_DIR="package/qnap"
BIN="dist/ps3netsrv-go-qnap-armv5"

# 1. build binary if missing
if [ ! -f "$BIN" ]; then
    echo ">> building ARMv5 binary ..."
    VERSION="$VERSION" ./scripts/build-qnap-armv5.sh
fi

# 2. stage binary into the arch dir
echo ">> staging binary into ${PKG_DIR}/arm-x19/ ..."
cp "$BIN" "${PKG_DIR}/arm-x19/ps3netsrv-go"
chmod +x "${PKG_DIR}/arm-x19/ps3netsrv-go"

mkdir -p dist

# 3. run qbuild
if command -v qbuild >/dev/null 2>&1; then
    echo ">> building .qpkg with native qbuild ..."
    qbuild --root "$PKG_DIR" --build-arch arm-x19 --exclude '.gitkeep' \
           --build-version "$CLEAN_VERSION" --build-dir "${REPO}/dist"
else
    echo ">> native qbuild not found; building via Docker (qdk-builder) ..."
    if ! docker image inspect qdk-builder >/dev/null 2>&1; then
        echo ">> building qdk-builder image ..."
        docker build -t qdk-builder -f scripts/qdk.Dockerfile scripts
    fi
    docker run --rm -v "${REPO}:/build" -w /build qdk-builder bash -lc "
        export PATH=/usr/share/QDK/bin:\$PATH
        qbuild --root '${PKG_DIR}' --build-arch arm-x19 --exclude '.gitkeep' \
               --build-version '${CLEAN_VERSION}' --build-dir /build/dist
    "
fi

echo
echo ">> Done. Resulting package(s):"
ls -la dist/*.qpkg 2>/dev/null || echo "   (no .qpkg found — check qbuild output above)"
