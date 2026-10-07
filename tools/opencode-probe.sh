#!/usr/bin/env bash
# Runs `opencode serve` once the way kawt will (temp folder, own config, no network extras,
# a random password, port 4097) and records what it answers: providers, config, a short
# session with one small file edit, the permission request it raises, the messages and
# the raw event stream. For wiring kawt's coder mode to the installed OpenCode version.
# Changes nothing outside a temp folder, which is removed at the end.
#
#   tools/opencode-probe.sh [model] [output file]
#   (model defaults to the one picked in kawt's ai panel; ollama must be running)

set -u
state=${XDG_STATE_HOME:-$HOME/.local/state}/kawt
model=${1:-$(sed -n 's/^ *"ollamaModel": *"\([^"]*\)".*/\1/p' "$state/settings.json" 2> /dev/null)}
model=${model:-llama3.2}
out=${2:-$HOME/claude_workspace/opencode-probe.txt}
port=4097
pass="probe-$RANDOM$RANDOM"
work=$(mktemp -d)
cfg=$work/opencode.json
url=http://127.0.0.1:$port

echo "hello from kawt" > "$work/hello.txt"
git -C "$work" init -q 2> /dev/null

# the config kawt would generate; baseURL placement is one of the things being checked
cat > "$cfg" << JSON
{
  "share": "disabled",
  "update": "disable",
  "websearch": false,
  "providers": {
    "ollama": {
      "name": "Ollama (local)",
      "package": "@ai-sdk/openai-compatible",
      "settings": { "baseURL": "http://127.0.0.1:11434/v1" },
      "models": { "$model": { "name": "$model" } }
    }
  },
  "model": "ollama/$model"
}
JSON

api() { curl -s -m 10 -u "opencode:$pass" "$@"; }

cleanup() {
    kill "$serve_pid" "$events_pid" 2> /dev/null
    wait 2> /dev/null
    rm -rf "$work"
}

(
    cd "$work" || exit 1
    OPENCODE_CONFIG=$cfg OPENCODE_SERVER_PASSWORD=$pass \
        OPENCODE_DISABLE_MODELS_FETCH=1 OPENCODE_DISABLE_AUTOUPDATE=1 \
        exec opencode serve --port "$port"
) > "$work/serve.log" 2>&1 &
serve_pid=$!
trap cleanup EXIT

echo "starting opencode serve on $url ..."
for _ in $(seq 1 30); do
    api "$url/api/config" > /dev/null && break
    sleep 0.5
done

{
    echo "== version"
    opencode --version
    echo
    echo "== model asked for: ollama/$model"
    echo
    echo "== GET /api/provider"
    api "$url/api/provider" | head -c 6000
    echo
    echo
    echo "== GET /api/config"
    api "$url/api/config" | head -c 3000
    echo
} > "$out"

# the raw event stream, while the session below runs
curl -s -N -u "opencode:$pass" "$url/api/event" > "$work/events.txt" 2>&1 &
events_pid=$!

body=$(printf '{"location":{"directory":"%s"},"model":{"providerID":"ollama","id":"%s"},"permissions":[{"action":"*","resource":"*","effect":"ask"}]}' "$work" "$model")
session=$(api -X POST -H 'Content-Type: application/json' -d "$body" "$url/api/session")
sid=$(printf '%s' "$session" | grep -o '"id":"ses[^"]*"' | head -n 1 | cut -d'"' -f4)
{
    echo
    echo "== POST /api/session"
    echo "$session" | head -c 2000
    echo
} >> "$out"

if [[ -n $sid ]]; then
    prompt='{"text":"Append the line probe ok to the file hello.txt, then reply with the single word done."}'
    {
        echo
        echo "== POST /api/session/$sid/prompt"
        api -X POST -H 'Content-Type: application/json' -d "$prompt" "$url/api/session/$sid/prompt" | head -c 2000
        echo
    } >> "$out"

    echo "waiting up to 60 s for the model to ask for the edit ..."
    for _ in $(seq 1 60); do
        perms=$(api "$url/api/session/$sid/permission")
        [[ $perms == *'"id":"per'* ]] && break
        sleep 1
    done
    {
        echo
        echo "== GET /api/session/$sid/permission (pending)"
        echo "$perms" | head -c 3000
        echo
    } >> "$out"

    # answer the first request with "once" to see the rest of the flow
    pid=$(printf '%s' "$perms" | grep -o '"id":"per[^"]*"' | head -n 1 | cut -d'"' -f4)
    if [[ -n $pid ]]; then
        {
            echo
            echo "== POST permission $pid reply once"
            api -X POST -H 'Content-Type: application/json' -d '{"decision":"once"}' "$url/api/session/$sid/permission/$pid/reply" | head -c 500
            echo
        } >> "$out"
        sleep 15
    fi

    {
        echo
        echo "== GET /api/session/$sid/message"
        api "$url/api/session/$sid/message" | head -c 12000
        echo
        echo
        echo "== hello.txt after"
        cat "$work/hello.txt"
    } >> "$out"
fi

sleep 1
{
    echo
    echo "== event stream (first 15000 bytes)"
    head -c 15000 "$work/events.txt"
    echo
    echo
    echo "== serve log"
    head -c 4000 "$work/serve.log"
} >> "$out"

echo "done: $out"
