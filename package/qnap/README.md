# PS3netsrv-go for QNAP

This directory packages `ps3netsrv-go` as an installable QNAP `.qpkg` for every
supported architecture, from legacy Marvell Kirkwood ARMv5 units (QTS 4.x,
uClibc) up to modern ARM64 / x86-64 models.

## Why a dedicated build

Stock/third-party QPKGs and the generic upstream `linux/arm` release fail on
older hardware:

| Problem | Cause | Fix in these builds |
|---|---|---|
| `undefined symbol: pthread_attr_getstacksize` | binary built with **cgo** against a newer libc | `CGO_ENABLED=0` |
| illegal instruction on ARMv5 | upstream `arm` release uses default **GOARM=7** | per-arch `GOARM` (5 for Kirkwood) |
| needs glibc `/lib/ld-linux.so.3` | `purego` dynamically links libc | `-tags nopurego` → fully static |
| PS3 ISOs (>2 GB) won't open on 32-bit | `os.Root` omits `O_LARGEFILE` | `osutil.StrictSystemRoot` wrapper (see `internal/osutil/strict_root.go`) |

## CHD support — compatibility disclaimer

> **CHD (MAME compressed disc image) support requires a QNAP with `glibc >= 2.21`
> and a hardware-FP CPU (x86-64, ARM64, or modern ARMv7).** Check yours over SSH
> with `ldd --version`. It is **not** available on legacy models: Marvell
> Kirkwood **ARMv5** (no hardware floating point) or units still on **QTS 4.3.x
> (glibc 2.17)**. All other formats (ISO / CSO / ZSO / PKG) work on **every**
> supported model.
>
> Accordingly, the **`x86_64` and `arm_64` packages ship with CHD enabled**
> (purego + a bundled `libchdr.so`); the **32-bit ARM packages are CHD-free
> static builds** that run on any QTS/libc. Grab the package matching your model,
> and if you specifically need CHD, confirm your glibc first.

This was verified on real hardware: CHD works on an x86-64 unit (glibc 2.21) and
a modern glibc; it is rejected by the QTS 4.3 loader (glibc 2.17) and impossible
on ARMv5 (purego's ARM call bridge uses VFP instructions the CPU lacks).

## Supported architectures

| QDK arch | Go target | Build | CHD | Hardware |
|---|---|---|---|---|
| `arm-x19` | `arm` GOARM=5 | static (nopurego) | no | Marvell Kirkwood ARMv5 (TS-x19/x12) |
| `arm-x31` | `arm` GOARM=7 | static (nopurego) | no | Marvell Armada ARMv7 (TS-x31) |
| `arm-x41` | `arm` GOARM=7 | static (nopurego) | no | Annapurna Alpine ARMv7 (TS-x41) |
| `arm_64` | `arm64` | purego + libchdr | **yes** | ARMv8 64-bit |
| `x86` | `386` | static (nopurego) | no | 32-bit Intel/Atom |
| `x86_64` | `amd64` | purego + libchdr | **yes** | 64-bit Intel/AMD |

## Building

Build one architecture:

```sh
VERSION=0.4.1 ./scripts/build-qnap-qpkg.sh arm-x19
# -> dist/ps3netsrv-go_0.4.1_arm-x19.qpkg
```

Build all architectures:

```sh
VERSION=0.4.1 ./scripts/build-qnap-all.sh
# -> dist/ps3netsrv-go_0.4.1_<arch>.qpkg  (one per arch)
```

The scripts cross-compile the static binary (Go, from a single host) and wrap it
with QNAP's `qbuild` (QDK). QDK only runs on Linux; if `qbuild` isn't on your
`PATH` the scripts use a local Docker image (`scripts/qdk.Dockerfile`) **for the
build only** — nothing Docker-related is installed on or required by the NAS.
`VERSION` must be ≤ 10 characters (QNAP's `QPKG_VER` limit).

### CI / releases

`.github/workflows/qnap-qpkg.yml` builds every architecture in a matrix. Push a
`v*` tag and it publishes a GitHub Release with all `.qpkg`s attached. This is
the maintenance loop: bump the pinned upstream version, tag, and every platform
is rebuilt and released.

## Package layout (QDK conventions)

- `qpkg.cfg` — package metadata (name `ps3netsrv-go`).
- `<arch>/ps3netsrv-go` — the static binary per arch (staged at build, gitignored).
- `shared/ps3netsrv-go.sh` — service control script (`start|stop|restart`).
- `config/config.ini` — default config, preserved across upgrades (`QPKG_CONFIG`).
- `package_routines` — install hook that auto-creates the `PS3` share + layout.

## Installing on the NAS

Copy the matching `.qpkg` to the NAS and install via **App Center → Install
Manually**. On install the package **auto-creates a shared folder `PS3`**
(open to everyone) with the standard [webMAN MOD layout][layout] (`GAMES`,
`PS3ISO`, `PSXISO`, `PS2ISO`, `PSPISO`, `BDISO`, `DVDISO`, `ROMS`, `GAMEI`,
`PKG`, `MOVIES`, `MUSIC`, `PICTURE`) and points the server at `/share/PS3` —
no SSH needed. Copy your PS3 ISOs into the `PS3ISO` subfolder from your PC.

[layout]: https://github.com/aldostools/webMAN-MOD/wiki/~-PS3-NET-Server

> The PS3 console connects to the daemon on TCP **38008** (netiso protocol),
> not to the SMB share. The share is only so you can copy games onto the NAS.

Service management: `/etc/init.d/ps3netsrv-go.sh {start|stop|restart}`. To serve a
different folder, edit `root` in `<install-path>/config.ini` (find it with
`/sbin/getcfg ps3netsrv-go Install_Path -f /etc/config/qpkg.conf`).

## Quick drop-in test (existing install)

To swap just the binary into an already-installed `ps3netsrv-go`:

```sh
scp dist/ps3netsrv-go-qnap-arm-x19 admin@<nas-ip>:/tmp/
# on the NAS:
QPKG=$(/sbin/getcfg ps3netsrv-go Install_Path -f /etc/config/qpkg.conf)
/etc/init.d/ps3netsrv-go.sh stop
cp /tmp/ps3netsrv-go-qnap-arm-x19 "$QPKG/ps3netsrv-go"; chmod +x "$QPKG/ps3netsrv-go"
/etc/init.d/ps3netsrv-go.sh start
netstat -an | grep 38008
```
