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

# CHD (MAME compressed disc image) support needs the purego build + an external
# libchdr.so loaded at runtime. That only works where the CPU has hardware FP
# (purego's call bridge uses VFP) AND the QTS glibc is recent enough (>= ~2.21)
# to load a modern shared library. The 64-bit arches are always modern QTS with
# hardware FP, so we enable CHD there. Legacy 32-bit ARM stays on the fully
# static nopurego build (CHD off) which runs on any QTS/libc:
#   - arm-x19 (ARMv5) has no VFP at all -> purego SIGILLs;
#   - arm-x31/arm-x41 (ARMv7) span old QTS 4.3 (glibc 2.17) where a purego build
#     may not even start. ISO/CSO/ZSO/PKG streaming is unaffected on all arches.
#
# qnap_arch_chd_target <qdk-arch>  ->  prints the C cross-compiler triple to
# build libchdr for (non-empty = CHD-enabled arch), or "" for static/no-CHD.
qnap_arch_chd_target() {
    case "$1" in
        x86_64) echo "x86_64" ;;   # native gcc
        arm_64) echo "aarch64" ;;  # aarch64-linux-gnu-gcc
        *)      echo "" ;;
    esac
}
