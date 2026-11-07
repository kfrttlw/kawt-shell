#!/bin/sh
# usage: hardware.sh                                what there is, as key=value lines
#        hardware.sh charge <battery> <start> <end>  the battery's charge thresholds (as root:
#                                                    kawt runs it through pkexec, which asks)
# For the profile's sys tab (services/Hardware.qml): the bios, the battery's charge thresholds
# (thinkpads and many other laptops have them), the keyboard light, the power profile. What a
# machine doesn't have, it doesn't print.

if [ "$1" = charge ]; then
    b=$2 start=$3 end=$4
    case $b in /sys/class/power_supply/BAT*) ;; *) exit 2 ;; esac
    case $start$end in *[!0-9]* | '') exit 2 ;; esac
    [ "$end" -le 100 ] && [ "$start" -lt "$end" ] || exit 2
    # start must stay under end: written before end and after it again, whichever way they move
    [ -e "$b/charge_control_start_threshold" ] && echo "$start" > "$b/charge_control_start_threshold" 2> /dev/null
    echo "$end" > "$b/charge_control_end_threshold" || exit 1
    [ -e "$b/charge_control_start_threshold" ] && { echo "$start" > "$b/charge_control_start_threshold" || exit 1; }
    exit 0
fi

echo "bios=$(cat /sys/class/dmi/id/bios_version 2> /dev/null)"
echo "code=$(cat /sys/class/dmi/id/product_name 2> /dev/null)"
for b in /sys/class/power_supply/BAT*; do
    [ -e "$b/charge_control_end_threshold" ] || continue
    echo "battery=$b"
    echo "chargestart=$(cat "$b/charge_control_start_threshold" 2> /dev/null)"
    echo "chargeend=$(cat "$b/charge_control_end_threshold" 2> /dev/null)"
    break
done
for l in /sys/class/leds/*kbd_backlight*; do
    [ -e "$l/brightness" ] || continue
    echo "kbd=${l##*/}"
    echo "kbdmax=$(cat "$l/max_brightness" 2> /dev/null)"
    echo "kbdlevel=$(cat "$l/brightness" 2> /dev/null)"
    break
done
command -v powerprofilesctl > /dev/null && echo "profile=$(powerprofilesctl get 2> /dev/null)"
exit 0
