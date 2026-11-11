#!/bin/sh
# kawt, kept running. hypr/kawt.lua (or kawt.conf) starts this at login, install.sh after an
# update. The shell runs here in the foreground; when it ends by a crash it's started again a
# second later, so the bar, the notifications and the lock before sleep don't just go away (a
# crash while the screen is locked locks it again: modules/lock/Lock.qml).
# It ends with the shell when that was meant: qs kill -c kawt-shell (install.sh does that), a
# plain kill or ctrl+c, or Hyprland gone (a log out).
# Five crashes within two minutes: it stops trying, and Hyprland says so (hyprctl notify).
# One at a time: started while another one keeps kawt, it waits 5 s for it to end, then leaves.

lock=${XDG_RUNTIME_DIR:-/tmp}/kawt-keep.lock
exec 9> "$lock" || exit 1
if command -v flock > /dev/null; then
    flock -w 5 9 || exit 0
fi

crashes="" # when the last ones were (seconds), the ones within two minutes
while :; do
    # the lock's file stays with this script, not with the shell
    qs -c kawt-shell 9>&-
    code=$?
    case $code in
        # meant: qs kill (0), ctrl+c, a kill (TERM, HUP)
        0 | 129 | 130 | 143) exit 0 ;;
    esac
    # Hyprland gone: nothing to come back to
    hyprctl version > /dev/null 2>&1 || exit 0
    now=$(date +%s)
    kept=""
    for t in $crashes $now; do
        [ $((now - t)) -lt 120 ] && kept="$kept $t"
    done
    crashes=$kept
    # shellcheck disable=SC2086 # counted by its words
    set -- $crashes
    if [ $# -ge 5 ]; then
        hyprctl notify 3 30000 0 "kawt crashed five times in two minutes and stays off. What it said: qs log -c kawt-shell. Start it again: log in again, or qs -c kawt-shell -d" > /dev/null 2>&1
        exit 1
    fi
    hyprctl notify 0 6000 0 "kawt crashed (exit $code) and starts again" > /dev/null 2>&1
    sleep 1
done
