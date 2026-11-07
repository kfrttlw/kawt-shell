#!/bin/sh
# usage: ddc.sh get | set <percent>
# The monitors' own brightness over DDC/CI (ddcutil), for a machine without a backlight (a
# desktop): services/Brightness.qml. All the monitors that answer, together.
#   get   finds them, remembers them, prints the first one's brightness in percent;
#         exit 1 if none answers (no ddcutil, no i2c-dev module, DDC/CI off in the monitor's menu)
#   set   every one found by get to <percent> (each monitor's own scale: most go to 100)
# ddcutil needs /dev/i2c-*: the i2c-dev module (the installer loads it at boot) and access for
# your user (ddcutil's udev rule gives it to whoever sits at the machine).

found=${XDG_RUNTIME_DIR:-/tmp}/kawt-ddc # "bus max" per line

case $1 in
    get)
        command -v ddcutil > /dev/null || exit 1
        # "   I2C bus:  /dev/i2c-4"
        buses=$(ddcutil detect --brief 2> /dev/null | sed -n 's|.*I2C bus: */dev/i2c-\([0-9]*\).*|\1|p')
        [ -n "$buses" ] || exit 1
        : > "$found.new"
        pct=""
        for b in $buses; do
            # "VCP 10 C 50 100": the current value and the most it goes to
            set -- $(ddcutil --bus "$b" getvcp 10 --brief 2> /dev/null)
            [ "$1" = VCP ] && [ "${5:-0}" -gt 0 ] 2> /dev/null || continue
            echo "$b $5" >> "$found.new"
            [ -n "$pct" ] || pct=$(($4 * 100 / $5))
        done
        mv "$found.new" "$found"
        [ -n "$pct" ] || exit 1
        echo "$pct"
        ;;
    set)
        p=$2
        case $p in '' | *[!0-9]*) exit 2 ;; esac
        [ -s "$found" ] || exit 1
        # all at once: each one takes a moment to answer
        while read -r b max; do
            ddcutil --bus "$b" setvcp 10 $((p * max / 100)) --noverify > /dev/null 2>&1 &
        done < "$found"
        wait
        ;;
    *)
        echo "usage: ddc.sh get | set <percent>" >&2
        exit 2
        ;;
esac
