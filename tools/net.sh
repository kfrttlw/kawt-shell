#!/usr/bin/env bash
# Who talks to the internet right now: every open connection that leaves this machine, by
# program. Changes nothing and asks nobody: addresses stay numbers (looking their names up
# would itself send a question to a dns server).
#
#   tools/net.sh          once
#   tools/net.sh -w       keeps watching: each new connection once, with the time (ctrl+c stops)
#   tools/net.sh -a       the local network too (router, printer, phone...), marked "lan"
#   sudo tools/net.sh     every program's (without sudo, the system's own services show as "?")
#
# The same is in the wifi panel, [who's out]: with each program's speed, [!] to close it or start
# it without internet from then on. Without internet from a terminal:
#   unshare --net --map-current-user <program>
#
# kawt itself shows nothing here while you just use the desktop, but for one git fetch to
# github a week (is there a new kawt; off in profile -> cfg). The rest of kawt's that goes out:
# the ai panel on an "api" provider you picked, ollama pull, the voice model's [get] (once),
# and install.sh / doctor.sh (pacman, the aur) while you run them.

watch=0 lan=0
while (($#)); do
    case $1 in
        -w | --watch) watch=1 ;;
        -a | --all) lan=1 ;;
        -h | --help)
            sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'unknown option: %s (see --help)\n' "$1" >&2
            exit 2
            ;;
    esac
    shift
done

command -v ss > /dev/null || {
    echo "ss is missing (it comes with iproute2)" >&2
    exit 1
}

# one line per connection, sorted:  firefox           140.82.112.3:443         tcp
#   ss: "tcp  0  0  192.168.1.30:52344  140.82.112.3:443  users:(("firefox",pid=1234,fd=88))"
conns() {
    ss -Htunp state established 2> /dev/null | awk -v lan="$lan" '
        {
            proto = $1
            peer = $5
            prog = "?"
            if (match($0, /users:\(\("[^"]+"/))
                prog = substr($0, RSTART + 9, RLENGTH - 10)
            # the address without the port: [2a00::1]:443 -> 2a00::1, 1.2.3.4:443 -> 1.2.3.4
            host = peer
            if (host ~ /^\[/) { sub(/^\[/, "", host); sub(/\].*$/, "", host) } else sub(/:[^:]*$/, "", host)
            sub(/^::ffff:/, "", host) # ipv4 written as ipv6
            sub(/%.*$/, "", host) # fe80::1%wlan0
            if (host ~ /^127\./ || host == "::1")
                next # this machine itself: ollama, kawt, ...
            local = host ~ /^(10\.|192\.168\.|169\.254\.|172\.(1[6-9]|2[0-9]|3[01])\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.)/ || host ~ /^(fe80|fc|fd)/
            if (local && !lan)
                next
            printf "%-16s %-40s %s%s\n", prog, peer, proto, local ? "  lan" : ""
        }' | sort -u
}

if ((!watch)); then
    out=$(conns)
    if [[ -n $out ]]; then
        printf '%s\n' "$out"
    else
        echo "nothing goes out right now"
    fi
    ((EUID)) && printf '\n(without sudo: programs of other users and system services show as "?")\n'
    exit 0
fi

# watching: what's new since the last look, once
declare -A seen
echo "watching (ctrl+c stops); new connections:"
while :; do
    while IFS= read -r line; do
        [[ -n $line && -z ${seen[$line]:-} ]] || continue
        seen[$line]=1
        printf '%s  %s\n' "$(date +%H:%M:%S)" "$line"
    done <<< "$(conns)"
    sleep 2
done
