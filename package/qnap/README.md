# PS3netsrv-go on legacy ARMv5 QNAP NAS

This directory packages `ps3netsrv-go` for **old Marvell Kirkwood ARMv5 QNAP
units** (TS-119 / TS-219 / TS-419 / TS-x12 class — `uname -m` reports
`armv5tel`), running QTS 4.x on **uClibc**.

## Why this exists

The stock/third-party QPKG and the generic upstream `linux/arm` release do not
run on this hardware:

| Problem | Cause | Fix in this build |
|---|---|---|
| `undefined symbol: pthread_attr_getstacksize` | binary built with **cgo** against a newer libc | `CGO_ENABLED=0` |
| would crash with illegal instruction | upstream `arm` release uses default **GOARM=7** | `GOARM=5` |
| needs `/lib/ld-linux.so.3` (glibc) | `purego` dynamically links libc | `-tags nopurego` → fully static |

Trade-off: `nopurego` drops optional **CHD** (compressed disc image) support,
which would otherwise need an external `libchdr.so` that is impractical to
provide on ARMv5. Plain ISO/PKG streaming is unaffected.

## Build the binary

From the repository root, with a Go toolchain installed:

```sh
./scripts/build-qnap-armv5.sh
# -> dist/ps3netsrv-go-qnap-armv5   (ELF 32-bit ARM EABI5, statically linked)
```

Confirm the output says **`statically linked`** (not `dynamically linked`).

## Option A — Quick drop-in test (existing PS3netsrvNG install)

If you already installed the myqnap.org `PS3netsrvNG` QPKG, just replace its
binary to validate the fix immediately:

```sh
# on your Mac/PC
scp dist/ps3netsrv-go-qnap-armv5 admin@<nas-ip>:/tmp/

# on the NAS (SSH), find the install path
QPKG=$(/sbin/getcfg PS3netsrvNG Install_Path -f /etc/config/qpkg.conf)
/etc/init.d/PS3netsrvNG.sh stop
cp /tmp/ps3netsrv-go-qnap-armv5 "$QPKG/ps3netsrv-go"
chmod +x "$QPKG/ps3netsrv-go"
/etc/init.d/PS3netsrvNG.sh start
# verify it is listening
netstat -an | grep 38008
```

Set the served directory by editing that package's `config.ini`
(`root = /share/PS3`) or exporting `PS3NETSRV_ROOT` before start.

## Option B — Build a proper .qpkg

One command builds the binary and wraps it into an installable `.qpkg`:

```sh
VERSION=0.0.1 ./scripts/build-qnap-qpkg.sh
# -> dist/PS3netsrvNG_<version>_arm-x19.qpkg
```

The script runs QNAP's `qbuild` (QDK). QDK only runs on Linux, so if `qbuild`
is not on your `PATH` the script builds and uses a local Docker image
(`scripts/qdk.Dockerfile`) **for the build only** — nothing Docker-related is
installed on or required by the NAS. `VERSION` must be ≤ 10 characters
(QNAP's `QPKG_VER` limit).

Package layout (QDK conventions):

- `qpkg.cfg` — package metadata (name `PS3netsrvNG`, arch `arm-x19`).
- `arm-x19/ps3netsrv-go` — the static binary (staged at build time, gitignored).
- `shared/ps3netsrv-go.sh` — service control script (`start|stop|restart`).
- `config/config.ini` — default config, preserved across upgrades
  (`QPKG_CONFIG`).

### Install on the NAS

Copy the `.qpkg` to the NAS and install via **App Center → Install Manually**,
or over SSH:

```sh
qpkg_cli --install /path/to/PS3netsrvNG_0.0.1_arm-x19.qpkg   # if available
# otherwise use App Center's "Install Manually" upload
```

Once installed it is managed via
`/etc/init.d/PS3netsrvNG.sh {start|stop|restart}`. Edit the served directory
in `<install-path>/config.ini` (`root = /share/PS3`); find the install path
with `/sbin/getcfg PS3netsrvNG Install_Path -f /etc/config/qpkg.conf`.
