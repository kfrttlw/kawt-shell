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
#                                                        be longer than 128 KiB. Prints the path it wrote,
#                                                        from the folder (links followed)
#   coder-tool.sh <folder> remove <path>                 delete a file (undo of a created one)
#
# What a command (`run`) changed, through pictures of the project (see pictures below):
#   coder-tool.sh <folder> snap [fresh]                  a picture now: prints its id. fresh: the old
#                                                        ones go first (nothing to take back any more)
#   coder-tool.sh <folder> changes <id>                  a new picture: its id, then what differs from <id>
#                                                        a file a line ("M 3 1 100644 100644<tab>path": how,
#                                                        lines added, removed (- for a binary), the modes),
#                                                        then "--" and the diff (cut when long)
#   coder-tool.sh <folder> restore <id> <id2>            everything that differs between them back as in <id>
#   coder-tool.sh <folder> put    <path> <id>            one file back as in <id> (gone if it wasn't there)
#   coder-tool.sh <folder> diff   <path> <id>|-|new      the diff of <path> since a picture, since the text
#                                                        on stdin (-), or since there was none (new);
#                                                        first a line: new, gone, changed or same
#
# exit 3: outside the folder · 4: bad folder · 5: not found · 6: not a text file · 2: usage
# 7: no pictures here (no git) · 8: the project is too big to keep pictures of

root=$(realpath -e -- "$1" 2> /dev/null) || exit 4
self=$(realpath -e -- "$0") || exit 2 # restore runs it again, from inside the project
cmd=$2
shift 2
nl='
'

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

# <path> as git names it (from the folder, no links followed in its last part) -> absolute,
# its folder checked to be inside root: for a file a command made or changed, which may be a
# link itself (it's put back or removed as a link, never followed)
inside() {
    case $1 in '' | /* | *"$nl"*) exit 3 ;; esac
    case $1 in */*) d=${1%/*} ;; *) d=. ;; esac
    d=$(realpath -m -- "$root/$d") || exit 3
    case "$d" in "$root" | "$root"/*) ;; *) exit 3 ;; esac
    printf '%s' "$d/${1##*/}"
}

# a file or a link is deleted, then the folders it leaves empty, while they weren't in picture
# <id> (folders the command made). Never a folder with something in it
drop() { # drop <path> <id>
    f=$(inside "$1") || return 3
    [ -d "$f" ] && [ ! -L "$f" ] && return 0
    rm -f -- "$f" || return 1
    d=${f%/*}
    while [ "$d" != "$root" ] && ! git cat-file -e "$2:${d#"$root"/}" 2> /dev/null &&
        ! grep -Fxzq -- "${d#"$root"/}" "$GIT_DIR/dirs-$2" 2> /dev/null && rmdir -- "$d" 2> /dev/null; do
        d=${d%/*}
    done
}

# Pictures: what a command did, to show it file by file and take it back. A picture is a git
# tree in kawt's own git folder for this project (~/.cache/kawt/coder/<name>-<hash>), with the
# project as its work tree. Never the project's own .git, and none of your git settings or the
# project's .gitattributes: a picture is the files byte for byte, and nothing in it runs (no
# hooks, filters, fsmonitor). What .gitignore hides is left out (build output), and so are
# node_modules and the like where none says so. Git keeps a file that didn't change only once
# and reads again only the files whose size or time changed, so the next picture is quick.
# A folder with its own git in the project is left out as well (git takes it for another
# project). Not used for a month: deleted.
pictures() {
    command -v git > /dev/null || exit 7
    cache=$(realpath -m -- "${XDG_CACHE_HOME:-$HOME/.cache}/kawt/coder")
    # the project holds the pictures' own folder (your home as the project): it would take
    # pictures of its pictures. Too big anyway
    case $cache/ in "$root"/*) exit 8 ;; esac
    name=$(printf '%s' "${root##*/}" | tr -c 'A-Za-z0-9._-' _ | cut -c1-40)
    GIT_DIR=$cache/$name-$(printf '%s' "$root" | sha256sum | cut -c1-16)
    if [ ! -f "$GIT_DIR/HEAD" ]; then
        find "$cache" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf -- {} + 2> /dev/null
        # yours alone: the copies are of projects that may be in folders only you can open
        mkdir -p -- "${cache%/*}" && { [ -d "$cache" ] || mkdir -m 700 -- "$cache"; } &&
            mkdir -p -- "$GIT_DIR/info" && git init -q --bare --template= -- "$GIT_DIR" || exit 7
        echo '* -text -filter -ident -eol -working-tree-encoding !diff !merge' > "$GIT_DIR/info/attributes"
        printf '%s/\n' node_modules __pycache__ .venv venv .tox .mypy_cache .pytest_cache .ruff_cache .gradle .next .zig-cache zig-cache zig-out > "$GIT_DIR/info/exclude"
    fi
    # all of it through the environment, so the sh -c below gets it too. Files over 1 MB are
    # kept but not compared line by line (a diff of them would take long and say little)
    export GIT_DIR GIT_WORK_TREE="$root" GIT_INDEX_FILE="$GIT_DIR/index" GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL=/dev/null GIT_LITERAL_PATHSPECS=1 GIT_CONFIG_COUNT=5 \
        GIT_CONFIG_KEY_0=core.bare GIT_CONFIG_VALUE_0=false \
        GIT_CONFIG_KEY_1=core.quotePath GIT_CONFIG_VALUE_1=false \
        GIT_CONFIG_KEY_2=core.bigFileThreshold GIT_CONFIG_VALUE_2=1m \
        GIT_CONFIG_KEY_3=advice.addEmbeddedRepo GIT_CONFIG_VALUE_3=false \
        GIT_CONFIG_KEY_4=gc.auto GIT_CONFIG_VALUE_4=0
    cd -- "$root" || exit 4
    # left by a job cut short (kawt closed): only kawt uses this folder, one job at a time
    rm -f -- "$GIT_DIR/index.lock"
}

# a picture of the project now: its id. Too big to keep (over 20000 files or 200 MB, what
# .gitignore hides doesn't count): exit 8, but not for the picture after a command (any): one
# from before it was taken, and without the one after, what it did couldn't be taken back
snap() { # snap [any]
    if [ "${1:-}" != any ]; then
        git ls-files -z -c -o --exclude-standard | xargs -0 -r stat -c %s -- 2> /dev/null |
            awk '{ n++; s += $1 } END { exit !(n <= 20000 && s <= 200 * 1024 * 1024) }' || exit 8
    fi
    # a folder with its own git and no commit yet stops git add: with --ignore-errors it's
    # just left out
    git add -A --ignore-errors > /dev/null 2>&1
    t=$(git write-tree 2> /dev/null) || exit 7
    # A picture has no empty folders: they're listed next to it, every one of them, so taking
    # back what a command made never takes a folder that was there already. git names only
    # the outermost of the ones with nothing in them (all files are in the picture by now),
    # find gives the ones inside it
    # shellcheck disable=SC2016 # expanded by that sh
    git ls-files -z -o --directory --exclude-standard 2> /dev/null | xargs -0 -r sh -c '
        for d; do
            case $d in */) find "${d%/}" -type d -print0 2> /dev/null ;; esac
        done' sh > "$GIT_DIR/dirs-$t"
    echo "$t"
}

# an id from kawt itself, checked all the same: it goes into git's arguments
id() {
    case $1 in '' | *[!0-9a-f]*) exit 2 ;; esac
}

# a diff for the panel: at most 150 lines a file and 1500 in all, each line at most 300
# characters
cut_diff() {
    awk '/^diff --git / { n = 0 } { if (++n > 150) next; if (++all > 1500) exit; print substr($0, 1, 300) }'
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
        mkdir -p -- "$d" && cat > "$p" && printf '%s' "${p#"$root"/}"
        ;;
    remove)
        p=$(resolve "${1:-}" exist) || exit $?
        [ -f "$p" ] && rm -f -- "$p"
        ;;
    snap)
        pictures
        if [ "${1:-}" = fresh ]; then
            git prune --expire=now 2> /dev/null
            rm -f -- "$GIT_DIR"/dirs-*
        fi
        snap
        ;;
    changes)
        id "${1:-}"
        pictures
        after=$(snap any) || exit $?
        echo "$after"
        # "--raw --numstat": first a line each with how and the modes, then the same files
        # (in the same order) with the lines added and removed
        git diff --no-renames --raw --numstat "$1" "$after" | awk -F '\t' '
            /^:/ { split($1, r, " "); n++; how[n] = r[5]; modes[n] = substr(r[1], 2) " " r[2]; next }
            { m++; print how[m] " " $1 " " $2 " " modes[m] "\t" $3 }'
        echo --
        git diff --no-renames --no-color --no-ext-diff --no-textconv -U2 "$1" "$after" | cut_diff
        ;;
    restore)
        id "${1:-}"
        id "${2:-}"
        pictures
        why=0
        # first the empty folders it made (git init makes some), then its new files: a link
        # where a folder was must go before the folder comes back
        [ -f "$GIT_DIR/dirs-$2" ] && xargs -0 -r sh -- "$self" "$root" unmade "$1" < "$GIT_DIR/dirs-$2"
        git diff --no-renames --name-only -z --diff-filter=A "$1" "$2" | xargs -0 -r sh -- "$self" "$root" drop "$1" || why=1
        if ! git diff --quiet --no-renames --diff-filter=MDT "$1" "$2"; then
            git diff --no-renames --name-only -z --diff-filter=MDT "$1" "$2" |
                git checkout -q "$1" --pathspec-from-file=- --pathspec-file-nul || why=1
        fi
        exit $why
        ;;
    unmade) # unmade <id> <folder>...: from restore above, the empty folders of a picture after
        # a command: the ones that weren't there in <id> go, with the empty ones in them
        id "${1:-}"
        pictures
        at=$1
        shift
        for p; do
            p=${p%/}
            grep -Fxzq -- "$p" "$GIT_DIR/dirs-$at" 2> /dev/null && continue
            git cat-file -e "$at:$p" 2> /dev/null && continue
            f=$(inside "$p") || continue
            [ -d "$f" ] && [ ! -L "$f" ] && find "$f" -depth -type d -empty -delete 2> /dev/null
        done
        exit 0
        ;;
    drop) # drop <id> <path>...: from restore above (the names come with no line breaks in the way)
        id "${1:-}"
        pictures
        why=0
        at=$1
        shift
        for p; do drop "$p" "$at" || why=1; done
        exit $why
        ;;
    put)
        id "${2:-}"
        f=$(inside "${1:-}") || exit 3
        pictures
        if git cat-file -e "$2:$1" 2> /dev/null; then
            git checkout -q "$2" -- "$1"
        else
            drop "$1" "$2"
        fi
        ;;
    diff)
        [ "${2:-}" = - ] || [ "${2:-}" = new ] || id "${2:-}"
        f=$(inside "${1:-}") || exit 3
        command -v git > /dev/null || exit 7
        base=$(mktemp) || exit 1
        trap 'rm -f "$base"' EXIT
        from=$base
        case $2 in
            -) cat > "$base" ;;
            new) from=/dev/null ;;
            *)
                pictures
                git cat-file blob "$2:$1" > "$base" 2> /dev/null || from=/dev/null
                ;;
        esac
        [ -e "$f" ] || [ -L "$f" ] || f=/dev/null
        # first how it went: new, gone, changed (or the same: changed with no diff after it)
        case $from:$f in
            /dev/null:/dev/null) echo same ;;
            /dev/null:*) echo new ;;
            *:/dev/null) echo gone ;;
            *) echo changed ;;
        esac
        # from / : no repository around to read settings from
        cd / || exit 1
        GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git -c core.bigFileThreshold=1m diff --no-index --no-color --no-ext-diff --no-textconv -U2 -- "$from" "$f" | cut_diff
        ;;
    *)
        exit 2
        ;;
esac
