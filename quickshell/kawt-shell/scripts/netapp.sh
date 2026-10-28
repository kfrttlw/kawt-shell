#!/bin/sh
# usage: netapp.sh kill <pid>...
#        netapp.sh find <pid> [<entry id> <command>]...
# For the wifi panel's [who's out] page (services/NetWho.qml). ss names the processes holding the
# connections; the program you'd close is often their parent (a browser's network process, an
# electron app's helper), so both start from the topmost process running the same file:
#   kill   asks that one to quit (SIGTERM: it can still save), once per program
#   find   which launcher entry starts it, printed (nothing when it can't be told):
#            a flatpak app by its own id
#            an entry whose command is that file (/usr/bin/firefox -> /usr/lib/firefox/firefox)
#            one whose command is a script next to it (google-chrome-stable -> /opt/google/chrome/)
#            one called like it (steam, Discord)

# the topmost process running the same file as $1
top() {
    p=$1
    exe=$(readlink "/proc/$p/exe" 2> /dev/null) || {
        echo "$p"
        return
    }
    while :; do
        pp=$(awk '/^PPid:/ { print $2 }' "/proc/$p/status" 2> /dev/null)
        [ -n "$pp" ] && [ "$pp" -gt 1 ] || break
        [ "$(readlink "/proc/$pp/exe" 2> /dev/null)" = "$exe" ] || break
        p=$pp
    done
    echo "$p"
}

lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

case $1 in
    kill)
        shift
        killed=" "
        for pid in "$@"; do
            t=$(top "$pid")
            case $killed in *" $t "*) continue ;; esac
            killed="$killed$t "
            kill -TERM "$t" 2> /dev/null
        done
        ;;
    find)
        p=$(top "$2")
        shift 2
        flatpak=$(sed -n 's/^name=//p' "/proc/$p/root/.flatpak-info" 2> /dev/null | head -n 1)
        exe=$(readlink "/proc/$p/exe" 2> /dev/null) || exit 0
        dir=${exe%/*}
        name=$(lower "${exe##*/}")
        comm=$(lower "$(cat "/proc/$p/comm" 2> /dev/null)")
        near=
        while [ $# -ge 2 ]; do
            id=$1 cmd=$2
            shift 2
            if [ -n "$flatpak" ]; then
                [ "$id" = "$flatpak" ] && echo "$id" && exit 0
                continue
            fi
            path=$(command -v -- "$cmd" 2> /dev/null) || continue
            real=$(readlink -f -- "$path")
            [ "$real" = "$exe" ] && echo "$id" && exit 0
            [ -n "$near" ] && continue
            # a script beside it, in a folder of its own (not /usr/bin: everything is there)
            case $dir in /bin | /sbin | /usr/bin | /usr/sbin | /usr/local/bin) ;; *) [ "${real%/*}" = "$dir" ] && near=$id ;; esac
            # comm is cut at 15 letters: telegram-deskto
            base=$(lower "${cmd##*/}")
            { [ "$base" = "$name" ] || [ "$(printf '%.15s' "$base")" = "$comm" ]; } && near=$id
        done
        [ -n "$near" ] && echo "$near"
        ;;
    *)
        sed -n '2,3p' "$0" | sed 's/^# \{0,1\}//' >&2
        exit 2
        ;;
esac
exit 0
