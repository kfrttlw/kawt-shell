#!/bin/sh
# The coder agent's hands (services/Coder.qml). Every path is checked to stay inside the
# project folder: realpath resolves ../ and symlinks, and anything that ends up outside is
# refused with exit 3 before it is touched.
#
#   coder-tool.sh <folder> list   <path>                 files under path (2 levels)
#   coder-tool.sh <folder> search <text> <path>          lines containing text
#   coder-tool.sh <folder> read   <path> [from] [to]     numbered lines
#   coder-tool.sh <folder> cat    <path>                 raw content (exit 5: no such file)
#   coder-tool.sh <folder> write  <path>  < content      create / overwrite (parents inside the folder);
#                                                        the content comes on stdin: an argument can't
#                                                        be longer than 128 KiB
#   coder-tool.sh <folder> remove <path>                 delete a file (undo of a created one)
#
# exit 3: outside the folder · 4: bad folder · 5: not found · 6: not a text file · 2: usage

root=$(realpath -e -- "$1" 2> /dev/null) || exit 4
cmd=$2
shift 2

# resolve <path> [must exist] -> absolute path inside root, or exit 3 / 5
resolve() {
    p=$(realpath -m -- "$root/$1") || exit 3
    case "$p" in
        "$root" | "$root"/*) ;;
        *) exit 3 ;;
    esac
    if [ "${2:-}" = exist ] && [ ! -e "$p" ]; then exit 5; fi
    printf '%s' "$p"
}

case $cmd in
    list)
        p=$(resolve "${1:-.}" exist) || exit $?
        cd -- "$p" || exit 5
        find . -maxdepth 2 -not -path '*/.git*' -not -path '*/node_modules*' -not -name . 2> /dev/null |
            sed 's|^\./||' | sort | while IFS= read -r f; do
                if [ -d "$f" ]; then printf '%s/\n' "$f"; else printf '%s\n' "$f"; fi
            done | head -n 200
        ;;
    search)
        [ -n "${1:-}" ] || exit 2
        p=$(resolve "${2:-.}" exist) || exit $?
        cd -- "$root" || exit 4
        rel=.
        [ "$p" != "$root" ] && rel=${p#"$root"/}
        grep -rnIF --exclude-dir=.git --exclude-dir=node_modules -- "$1" "$rel" 2> /dev/null | sed 's|^\./||' |
            cut -c1-200 | head -n 80
        ;;
    read)
        p=$(resolve "${1:-}" exist) || exit $?
        [ -f "$p" ] || exit 5
        [ -s "$p" ] && ! grep -Iq . -- "$p" && exit 6
        # numbers only: these come from the model, and on a shell like bash a "number" such as
        # a[$(cmd)] inside $(( )) would run cmd
        from=${2:-1}
        to=${3:-}
        case $from in '' | *[!0-9]*) from=1 ;; esac
        case $to in '' | *[!0-9]*) to=$((from + 299)) ;; esac
        awk -v a="$from" -v b="$to" 'NR >= a && NR <= b { printf "%5d| %s\n", NR, $0 } END { if (NR > b) printf "... (%d lines in total)\n", NR }' "$p"
        ;;
    cat)
        p=$(resolve "${1:-}" exist) || exit $?
        [ -f "$p" ] || exit 5
        [ -s "$p" ] && ! grep -Iq . -- "$p" && exit 6
        cat -- "$p"
        ;;
    write)
        p=$(resolve "${1:-}") || exit $?
        d=$(dirname -- "$p")
        # the parent may not exist yet, but must also be inside
        case "$(realpath -m -- "$d")" in "$root" | "$root"/*) ;; *) exit 3 ;; esac
        mkdir -p -- "$d" && cat > "$p"
        ;;
    remove)
        p=$(resolve "${1:-}" exist) || exit $?
        [ -f "$p" ] && rm -f -- "$p"
        ;;
    *)
        exit 2
        ;;
esac
