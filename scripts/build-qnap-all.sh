#!/usr/bin/env bash
#
# Build .qpkg packages for every supported QNAP architecture.
# Mostly useful locally; CI builds each arch as a separate matrix job.
#
# Usage: [VERSION=x.y.z] scripts/build-qnap-all.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/qnap-arches.sh
. scripts/qnap-arches.sh

for arch in $QNAP_ARCHES; do
    echo "==================================================================="
    echo ">> $arch"
    echo "==================================================================="
    ./scripts/build-qnap-qpkg.sh "$arch"
done

echo
echo ">> All packages:"
ls -la dist/*.qpkg
