#!/usr/bin/env bash
#
# Shared mapping of QNAP/QDK architecture names to Go build targets.
# Sourced by the build scripts. All QNAP builds are CGO-free static
# (-tags nopurego) for maximum compatibility across QTS versions and libc
# variants (glibc/uClibc/musl).
#
# QDK arch     Go target        Hardware
# ----------   --------------   --------------------------------------------
# arm-x19      arm   GOARM=5    Marvell Kirkwood ARMv5 (TS-x19/x12, uClibc)
# arm-x31      arm   GOARM=7    Marvell Armada 37x/38x ARMv7 (TS-x31)
# arm-x41      arm   GOARM=7    Annapurna Alpine ARMv7 (TS-x41)
# arm_64       arm64            ARMv8 64-bit (TS-x32/x33/... ARM64)
# x86          386              32-bit Intel/Atom (legacy)
# x86_64       amd64            64-bit Intel/AMD

# All architectures we build for. Override with QNAP_ARCHES env if needed.
QNAP_ARCHES="${QNAP_ARCHES:-arm-x19 arm-x31 arm-x41 arm_64 x86 x86_64}"

# qnap_arch_to_go <qdk-arch>  ->  prints "GOARCH GOARM" (GOARM empty if n/a)
qnap_arch_to_go() {
    case "$1" in
        arm-x19) echo "arm 5" ;;
        arm-x31) echo "arm 7" ;;
        arm-x41) echo "arm 7" ;;
        arm_64)  echo "arm64 " ;;
        x86)     echo "386 " ;;
        x86_64)  echo "amd64 " ;;
        *) echo "unsupported QNAP arch: $1" >&2; return 1 ;;
    esac
}
