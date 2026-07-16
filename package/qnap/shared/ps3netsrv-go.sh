#!/bin/sh
#
# QNAP QPKG service script for ps3netsrv-go (static ARMv5 build).
# Compatible with the QDK service-program convention (start|stop|restart).
#
CONF=/etc/config/qpkg.conf
QPKG_NAME="PS3netsrvNG"
QPKG_ROOT=$(/sbin/getcfg "$QPKG_NAME" Install_Path -f "$CONF")

BIN="$QPKG_ROOT/ps3netsrv-go"
CONFIG="$QPKG_ROOT/config.ini"
PIDFILE="$QPKG_ROOT/ps3netsrv-go.pid"
LOGFILE="$QPKG_ROOT/ps3netsrv-go.log"

# Root directory served to the PS3. Override in $QPKG_ROOT/config.ini
# (root = ...) or via the PS3NETSRV_ROOT environment variable.
export PATH="$QPKG_ROOT:$PATH"

is_running() {
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

start() {
    if is_running; then
        echo "$QPKG_NAME is already running (pid $(cat "$PIDFILE"))."
        return 0
    fi
    if [ ! -x "$BIN" ]; then
        echo "ERROR: server binary not found or not executable: $BIN"
        return 1
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
        return 1
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
    *)       echo "Usage: $0 {start|stop|restart}"; exit 1 ;;
esac

exit 0
