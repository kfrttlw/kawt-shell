#!/bin/sh
# usage: sandbox.sh check
#        sandbox.sh <folder> <seconds> <command>
# The coder's `run` (services/Coder.qml), only after you pressed Run: <command> in sh,
# inside the project folder, shut off from everything else.
#   bwrap (bubblewrap, the default): the folder is /work, the one place it can write (git's
#     own folders in it read-only, see gitPlaces); /usr and a few files of /etc read-only; its
#     own empty /tmp, /proc, /dev; no network (an empty one of its own), no other processes, no
#     home, no session bus, a clean environment
#   podman (KAWT_SANDBOX=podman KAWT_IMAGE=<an image you pulled>, never pulled by itself):
#     --network=none, the folder at /work, files stay yours (keep-id)
# Limits: <seconds>, then it's killed (exit 124); 2 GB of memory and 256 processes (through
# systemd-run when there's a user manager); the output cut at 64 KB.
# Stopped (TERM, kawt's Stop): the command is stopped and the rest still runs (exit 143).
# After it: git folders the command made are renamed and named in the output (gitPlaces).
#   check   prints what there is ("bwrap" / "podman <image>"), exit 1 if nothing works
# Exit: the command's own; 124 timed out; 125 no sandbox (it never runs outside one).

sandbox=${KAWT_SANDBOX:-bwrap}
image=${KAWT_IMAGE:-}
keep="" # the list of git places to keep read-only, filled before a run (gitPlaces)
pidFile="" # the command's pid while it runs (timeout's), for a stop

# A git folder runs what its settings say: core.fsmonitor on a plain `git status`, which the
# kawt prompt does on every cd, hooks on a commit. One the command made or changed would run
# that outside, with your network and home. So every place git takes as its own is found
# before the run and made read-only for it, and after it any new one is renamed (never
# deleted: it could be a folder of yours moved there): each .git (folder, file or link) and
# each HEAD with refs or commondir next to it (a bare repository: git takes it as well once
# you cd there).
#   gitPlaces <folder> before <list> <paths>: one line in <list> for each, the same while it's
#     the same thing ("<device>:<inode> <type> <checksum of a link's target>", even when
#     moved), and its path in <paths>
#   gitPlaces <folder> after <list>: renames the ones not in <list>, a line about each
gitPlaces() {
    find "$1" \( -name .git -prune -o -name HEAD ! -type d \) -exec sh -c '
        root=$1 when=$2 list=$3 paths=$4
        shift 4
        for p; do
            case $p in */HEAD) [ -e "${p%/HEAD}/refs" ] || [ -e "${p%/HEAD}/commondir" ] || continue ;; esac
            id=$(stat -c "%d:%i %F" -- "$p") || continue
            id="$id $(readlink -- "$p" | cksum)"
            if [ "$when" = before ]; then
                echo "$id" >> "$list"
                printf "%s\n" "$p" >> "$paths"
            elif ! grep -Fxq -- "$id" "$list"; then
                to=$p.kawt-blocked n=1
                while [ -e "$to" ] || [ -L "$to" ]; do
                    n=$((n + 1))
                    to=$p.kawt-blocked$n
                done
                mv -- "$p" "$to" && echo "[sandbox] the command made or changed ${p#"$root"/}, which git would take as its own (its settings could run anything on your next git status, outside the sandbox): renamed to ${to#"$root"/}"
            fi
        done' sh "$1" "$2" "$3" "${4:-}" {} +
}

# sandboxed <folder> <seconds> <command>: the command, shut in; its exit code
sandboxed() {
    root=$1 secs=$2 cmd=$3
    if [ "$sandbox" = podman ]; then
        [ -n "$image" ] && command -v podman > /dev/null || return 125
        # the folder itself one of git's places (a bare repository): all of it read-only, as
        # podman takes only one folder at /work
        mode=Z
        [ -n "$keep" ] && grep -Fxq -e "$root/HEAD" -e "$root" "$keep" && mode=ro,Z
        set -- podman run --rm --name "kawt-run-$$" --pull=never --network=none --userns=keep-id \
            --memory 2g --pids-limit 256 --cpus 2 --cap-drop all --security-opt no-new-privileges \
            -v "$root:/work:$mode"
        if [ -n "$keep" ]; then
            while IFS= read -r p; do
                case $p in */HEAD) p=${p%/HEAD} ;; *) [ -L "$p" ] && continue ;; esac
                [ "$p" = "$root" ] || set -- "$@" -v "$p:/work${p#"$root"}:ro"
            done < "$keep"
        fi
        set -- "$@" -w /work "$image" sh -c "$cmd"
    else
        command -v bwrap > /dev/null || return 125
        set -- bwrap --unshare-all --die-with-parent --new-session --hostname sandbox \
            --ro-bind /usr /usr --proc /proc --dev /dev --tmpfs /tmp --tmpfs /run --dir /tmp/home \
            --bind "$root" /work --chdir /work \
            --clearenv --setenv PATH /usr/local/bin:/usr/bin --setenv HOME /tmp/home \
            --setenv TMPDIR /tmp --setenv TERM dumb --setenv LANG "${LANG:-C.UTF-8}"
        # /bin, /lib...: links into /usr on most systems now, folders on a few
        for d in /bin /sbin /lib /lib64; do
            if [ -L "$d" ]; then
                set -- "$@" --symlink "$(readlink "$d")" "$d"
            elif [ -d "$d" ]; then
                set -- "$@" --ro-bind "$d" "$d"
            fi
        done
        # what programs need from /etc to start (libraries, users, time, certificates); nothing else
        for f in /etc/ld.so.cache /etc/ld.so.conf /etc/ld.so.conf.d /etc/passwd /etc/group \
            /etc/nsswitch.conf /etc/localtime /etc/locale.conf /etc/ssl /etc/ca-certificates \
            /etc/alternatives /etc/profile /etc/bash.bashrc /etc/os-release; do
            [ -e "$f" ] && set -- "$@" --ro-bind "$f" "$f"
        done
        # git's own places read-only (a bare repository: all of its folder). A link can't be
        # made read-only, but a changed one is caught after the run all the same
        if [ -n "$keep" ]; then
            while IFS= read -r p; do
                case $p in */HEAD) p=${p%/HEAD} ;; *) [ -L "$p" ] && continue ;; esac
                set -- "$@" --ro-bind "$p" "/work${p#"$root"}"
            done < "$keep"
        fi
        set -- "$@" sh -c "$cmd"
    fi
    # memory and process limits, when a user manager can give them
    limit=""
    if command -v systemd-run > /dev/null && [ -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]; then
        limit="systemd-run --user --scope --quiet --collect -p MemoryMax=2G -p TasksMax=256 --"
    fi
    # in the background, its pid written down, so a stop can reach it (see the trap below):
    # whichever comes second, the pid or the stop, sees the other
    # shellcheck disable=SC2086 # $limit is words on purpose
    $limit timeout -k 5 "$secs" "$@" < /dev/null &
    if [ -n "$pidFile" ]; then
        echo $! > "$pidFile"
        [ -e "$pidFile.stop" ] && kill -TERM $! 2> /dev/null
    fi
    wait $!
    rc=$?
    # ended: its pid may be someone else's soon, and a stop from now on has nothing to stop
    [ -n "$pidFile" ] && : > "$pidFile"
    # podman's container lives on (in conmon) when the time is up and only podman is killed: it's
    # stopped here, before the git folders are looked at
    [ "$sandbox" = podman ] && podman kill "kawt-run-$$" > /dev/null 2>&1 && podman rm -f "kawt-run-$$" > /dev/null 2>&1
    return $rc
}

# works here? (user namespaces can be off on some kernels; the image may not be pulled)
works() {
    if [ "$sandbox" = podman ]; then
        [ -n "$image" ] && command -v podman > /dev/null && podman image exists "$image" 2> /dev/null
        return
    fi
    t=$(mktemp -d) || return 1
    sandboxed "$t" 10 true > /dev/null 2>&1
    ok=$?
    rmdir "$t"
    return $ok
}

if [ "$1" = check ]; then
    works || exit 1
    case $sandbox in podman) echo "podman $image" ;; *) echo bwrap ;; esac
    exit 0
fi

dir=$(realpath -e -- "$1" 2> /dev/null) || exit 125
case $2 in '' | *[!0-9]*) limitSecs=120 ;; *) limitSecs=$2 ;; esac
[ -d "$dir" ] && [ -n "$3" ] || exit 125
works || {
    echo "no sandbox: install bubblewrap (or set up podman), nothing runs without one"
    exit 125
}

code=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/kawt-run.XXXXXX") || exit 125
ids=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/kawt-run.XXXXXX") || exit 125
keep=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/kawt-run.XXXXXX") || exit 125
errs=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/kawt-run.XXXXXX") || exit 125
pidFile=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/kawt-run.XXXXXX") || exit 125
trap 'rm -f "$code" "$ids" "$keep" "$errs" "$pidFile" "$pidFile.stop"' EXIT
# Stop in kawt sends TERM here. Without a trap sh would just end, and the command would go on
# to its time limit with nobody looking for git folders after it. So the command gets the TERM
# (timeout passes it on: bwrap ends and takes the sandbox with it, podman stops the container)
# and the rest of this script runs as always
trap 'touch "$pidFile.stop"; [ -s "$pidFile" ] && kill -TERM "$(cat "$pidFile")" 2> /dev/null' TERM INT HUP
gitPlaces "$dir" before "$ids" "$keep" 2> "$errs"
# a folder of yours it couldn't look into: the command could open it (it's yours), and a git
# folder in it wouldn't be read-only. Someone else's (root's) it can't open either
if [ -s "$errs" ]; then
    locked=$(find "$dir" -type d -user "$(id -u)" \( ! -readable -o ! -executable \) -print -quit 2> /dev/null)
    if [ -n "$locked" ]; then
        echo "${locked#"$dir"/} can't be looked into for git folders (they'd be writable for the command): nothing runs. chmod u+rx it, or move it out of the project"
        exit 125
    fi
fi
# a path with a line break would be two lines in the list, and its place not read-only
if [ "$(wc -l < "$ids")" != "$(wc -l < "$keep")" ]; then
    echo "a git folder here has a line break in its path: it can't be kept read-only, nothing runs"
    exit 125
fi
if [ "$sandbox" = podman ] && grep -q : "$keep"; then
    echo "a git folder here has a : in its path: podman can't keep it read-only, nothing runs"
    exit 125
fi
[ -e "$pidFile.stop" ] && exit 143
# head stops a flood of output: the command gets a broken pipe and ends. In the background, as
# only a wait can be cut short by the TERM; it's waited for again until all of it has ended
{
    sandboxed "$dir" "$limitSecs" "$3" 2>&1
    echo $? > "$code"
} | head -c 65536 &
while ! wait; do :; done
# after the cut, so it's never lost in a long output
gitPlaces "$dir" after "$ids" 2> "$errs"
if [ -s "$errs" ]; then
    echo "[sandbox] some folders couldn't be looked into for git folders the command made:"
    head -n 5 "$errs"
fi
exit "$(cat "$code" 2> /dev/null || echo 1)"
