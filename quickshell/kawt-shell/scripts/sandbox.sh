#!/bin/sh
# usage: sandbox.sh check
#        sandbox.sh <folder> <seconds> <command>
# The coder's `run` (services/Coder.qml), only after you pressed [run]: <command> in sh,
# inside the project folder, shut off from everything else.
#   bwrap (bubblewrap, the default): the folder is /work, the one place it can write (its .git
#     read-only: no hooks); /usr and a few files of /etc read-only; its own empty /tmp, /proc,
#     /dev; no network (an empty one of its own), no other processes, no home, no session bus,
#     a clean environment
#   podman (KAWT_SANDBOX=podman KAWT_IMAGE=<an image you pulled>, never pulled by itself):
#     --network=none, the folder at /work, files stay yours (keep-id)
# Limits: <seconds>, then it's killed (exit 124); 2 GB of memory and 256 processes (through
# systemd-run when there's a user manager); the output cut at 64 KB.
#   check   prints what there is ("bwrap" / "podman <image>"), exit 1 if nothing works
# Exit: the command's own; 124 timed out; 125 no sandbox (it never runs outside one).

sandbox=${KAWT_SANDBOX:-bwrap}
image=${KAWT_IMAGE:-}

# sandboxed <folder> <seconds> <command>: the command, shut in; its exit code
sandboxed() {
    root=$1 secs=$2 cmd=$3
    if [ "$sandbox" = podman ]; then
        [ -n "$image" ] && command -v podman > /dev/null || return 125
        set -- podman run --rm --pull=never --network=none --userns=keep-id \
            --memory 2g --pids-limit 256 --cpus 2 --cap-drop all --security-opt no-new-privileges \
            -v "$root:/work:Z" -w /work "$image" sh -c "$cmd"
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
        # git's own folder read-only: a hook written there would run outside, on your next commit
        [ -d "$root/.git" ] && set -- "$@" --ro-bind "$root/.git" /work/.git
        set -- "$@" sh -c "$cmd"
    fi
    # memory and process limits, when a user manager can give them
    limit=""
    if command -v systemd-run > /dev/null && [ -S "${XDG_RUNTIME_DIR:-/nonexistent}/bus" ]; then
        limit="systemd-run --user --scope --quiet --collect -p MemoryMax=2G -p TasksMax=256 --"
    fi
    # shellcheck disable=SC2086 # $limit is words on purpose
    $limit timeout -k 5 "$secs" "$@" < /dev/null
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
trap 'rm -f "$code"' EXIT
# head stops a flood of output: the command gets a broken pipe and ends
{
    sandboxed "$dir" "$limitSecs" "$3" 2>&1
    echo $? > "$code"
} | head -c 65536
exit "$(cat "$code" 2> /dev/null || echo 1)"
