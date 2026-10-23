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
# libchdr.so loaded at runtime. purego's ARM call bridge historically required
# hardware FP (VFP), which the ARMv5 Kirkwood lacks; purego v0.11.1 adds proper
# ARM soft-float support (verified on a real ARMv5 unit), so arm-x19 is now
# CHD-capable too. Its libchdr must be built ARMv5TE soft-float against an old
# glibc (see build-libchdr.sh); the 64-bit arches use a plain modern-glibc lib.
# arm-x31/arm-x41 (ARMv7) are left static for now (old QTS 4.3 glibc 2.17).
# ISO/CSO/ZSO/PKG streaming is unaffected on all arches.
#
# qnap_arch_chd_target <qdk-arch>  ->  prints a libchdr build target
# (non-empty = CHD-enabled arch), or "" for static/no-CHD.
qnap_arch_chd_target() {
    case "$1" in
        x86_64)  echo "x86_64" ;;        # native gcc
        arm_64)  echo "aarch64" ;;       # aarch64-linux-gnu-gcc
        arm-x19) echo "arm-softfloat" ;; # ARMv5TE soft-float, old glibc, lowram libchdr
        *)       echo "" ;;
    esac
}
