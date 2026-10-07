#!/usr/bin/env bash
# How much kawt (the qs process) takes right now: RAM and GPU memory. Changes nothing.
#
#   tools/mem.sh           once
#   tools/mem.sh -w        every 2 s: watch it while opening and closing panels
#   tools/mem.sh -p <pid>  another process
#
# ram   rss: everything it has mapped, shared libraries included (what top shows)
#       pss: its fair share of what's shared with other programs
#       own: what only it uses, what you'd get back by closing it
# gpu   what the graphics driver keeps for it (/proc/<pid>/fdinfo, kernel 5.19+, no root)
#
# For a fair before / after: start kawt, wait half a minute, measure; then do the same thing
# (open the profile, close it...) each time.

watch=0 pid=""
while (($#)); do
    case $1 in
        -w | --watch) watch=1 ;;
        -p | --pid)
            pid=${2:-}
            shift
            ;;
        -h | --help)
            sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'unknown option: %s (see --help)\n' "$1" >&2
            exit 2
            ;;
    esac
    shift
done

# the qs running kawt-shell (any qs if the command line doesn't say)
find_pid() {
    local p
    for p in $(pgrep -x qs; pgrep -x quickshell); do
        tr '\0' ' ' < "/proc/$p/cmdline" 2> /dev/null | grep -q "kawt-shell" && {
            echo "$p"
            return
        }
    done
    pgrep -x qs | head -n 1
}

mb() { awk -v k="$1" 'BEGIN { printf "%.0f MB", k / 1024 }'; }

ram() {
    awk '/^Rss:/ {r = $2} /^Pss:/ {p = $2} /^Private_(Clean|Dirty):/ {o += $2} /^Swap:/ {s = $2}
        END { printf "%d %d %d %d\n", r, p, o, s }' "/proc/$1/smaps_rollup"
}

# per driver client: the largest value seen for each region (one client can sit behind several
# fds); then summed over clients. Prefers "resident", then "memory", then "total" figures.
gpu() {
    local f
    for f in /proc/"$1"/fdinfo/*; do
        grep -q '^drm-client-id' "$f" 2> /dev/null || continue
        awk '/^drm-client-id/ {id = $2}
            /^drm-(resident|memory|total)-[a-z0-9]+:/ {
                k = $1; sub(":", "", k); v = $2; u = $3
                if (u == "MiB") v *= 1024; else if (u == "GiB") v *= 1048576; else if (u == "" || u == "B") v /= 1024
                print id, k, v
            }' "$f"
    done | awk '
        { key = $1 SUBSEP $2; if (!(key in m) || $3 > m[key]) m[key] = $3 }
        END {
            for (ck in m) { split(ck, a, SUBSEP); sum[a[2]] += m[ck] }
            fam = ""
            for (k in sum) if (k ~ /^drm-resident-/) fam = "drm-resident-"
            if (fam == "") for (k in sum) if (k ~ /^drm-memory-/) fam = "drm-memory-"
            if (fam == "") fam = "drm-total-"
            out = ""
            for (k in sum) if (index(k, fam) == 1) out = out sprintf("%s%s %.0f MB", out == "" ? "" : " · ", substr(k, length(fam) + 1), sum[k] / 1024)
            print out
        }'
}

show() {
    local r p o s g
    read -r r p o s < <(ram "$pid")
    g=$(gpu "$pid")
    printf '%s  ram  rss %s · pss %s · own %s · swap %s\n' "$(date +%H:%M:%S)" "$(mb "$r")" "$(mb "$p")" "$(mb "$o")" "$(mb "$s")"
    printf '          gpu  %s\n' "${g:-nothing reported (driver without fdinfo accounting)}"
}

[[ -n $pid ]] || pid=$(find_pid)
if [[ -z $pid || ! -r /proc/$pid/smaps_rollup ]]; then
    echo "kawt isn't running (no qs process found)" >&2
    exit 1
fi
printf 'qs pid %s: %s\n' "$pid" "$(tr '\0' ' ' < "/proc/$pid/cmdline")"
show
while ((watch)); do
    sleep 2
    show
done
