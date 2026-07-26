#!/bin/sh
#
# QNAP QPKG service script for ps3netsrv-go (static ARMv5 build).
# Follows the QDK service-program convention (start|stop|restart|remove).
#
CONF=/etc/config/qpkg.conf
QPKG_NAME="ps3netsrv-go"
QPKG_ROOT=$(/sbin/getcfg "$QPKG_NAME" Install_Path -f "$CONF")
export QNAP_QPKG=$QPKG_NAME

BIN="$QPKG_ROOT/ps3netsrv-go"
CONFIG="$QPKG_ROOT/config.ini"
PIDFILE="$QPKG_ROOT/ps3netsrv-go.pid"
LOGFILE="$QPKG_ROOT/ps3netsrv-go.log"

# CHD-enabled (purego) builds bundle a libchdr.so beside the binary; make it
# discoverable by purego's dlopen. On glibc < 2.34 the pthread_* symbols live in
# libpthread, so preload it when present. Both are harmless no-ops on the static
# (nopurego) builds, which ship no libchdr.so and never dlopen.
export LD_LIBRARY_PATH="$QPKG_ROOT:$LD_LIBRARY_PATH"
[ -e /lib/libpthread.so.0 ] && export LD_PRELOAD="/lib/libpthread.so.0:$LD_PRELOAD"

is_running() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

start() {
    ENABLED=$(/sbin/getcfg "$QPKG_NAME" Enable -u -d FALSE -f "$CONF")
    if [ "$ENABLED" != "TRUE" ]; then
        echo "$QPKG_NAME is disabled."
        exit 1
    fi
    if is_running; then
        echo "$QPKG_NAME is already running (pid $(cat "$PIDFILE"))."
        return 0
    fi
    if [ ! -x "$BIN" ]; then
        echo "ERROR: server binary not found or not executable: $BIN"
        exit 1
    fi
    echo "Starting $QPKG_NAME ..."
    # Run detached; capture stdout/stderr for troubleshooting.
    "$BIN" server --config="$CONFIG" >>"$LOGFILE" 2>&1 &
    echo $! > "$PIDFILE"
    sleep 1
    if is_running; then
        echo "$QPKG_NAME started (pid $(cat "$PIDFILE"))."
    else
        echo "ERROR: $QPKG_NAME failed to start. Last log lines:"
        tail -n 20 "$LOGFILE" 2>/dev/null
        rm -f "$PIDFILE"
        exit 1
    fi
}

stop() {
    if is_running; then
        echo "Stopping $QPKG_NAME ..."
        kill "$(cat "$PIDFILE")" 2>/dev/null
        sleep 2
        kill -9 "$(cat "$PIDFILE")" 2>/dev/null
    fi
    rm -f "$PIDFILE"
    echo "$QPKG_NAME stopped."
}

case "$1" in
  start)   start ;;
  stop)    stop ;;
  restart) stop; start ;;
  remove)  ;;
  *)       echo "Usage: $0 {start|stop|restart|remove}"; exit 1 ;;
esac

exit 0
