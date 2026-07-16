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

## Option B — Build a proper .qpkg (QDK)

On a Linux host with the QNAP [QDK](https://github.com/qnap-dev/QDK):

```sh
# stage the built binary and config into this package dir
cp dist/ps3netsrv-go-qnap-armv5 package/qnap/shared/ps3netsrv-go
cp package/qnap/config/config.ini package/qnap/shared/config.ini
qbuild --build-dir package/qnap
```

The resulting `.qpkg` installs to App Center and is managed via
`/etc/init.d/PS3netsrvNG.sh {start|stop|restart}`.
