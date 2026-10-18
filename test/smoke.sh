#!/bin/sh
set -eu

engine=${CONTAINER_ENGINE:-docker}
image=${1:-opencode-railway-lite:check}
name="opencode-lite-smoke-$$"
volume="${name}-data"

cleanup() {
    "$engine" rm -f "$name" >/dev/null 2>&1 || true
    "$engine" volume rm "$volume" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

if "$engine" run --rm "$image" >/dev/null 2>&1; then
    echo "FAIL: startup accepted a missing password" >&2
    exit 1
fi
if "$engine" run --rm -e OPENCODE_PASSWORD=test-only-not-a-real-secret \
    -e PORT=invalid "$image" >/dev/null 2>&1; then
    echo "FAIL: startup accepted an invalid port" >&2
    exit 1
fi

"$engine" volume create "$volume" >/dev/null

start() {
    "$engine" run -d --name "$name" --memory 1g --cpus 2 \
        -e OPENCODE_PASSWORD=test-only-not-a-real-secret \
        -v "$volume:/data" "$image" >/dev/null
    attempts=0
    until "$engine" exec "$name" sh -c \
        'curl --noproxy "*" -g -fsS -u "opencode:$OPENCODE_PASSWORD" http://[::1]:4096/api/info >/dev/null' \
        2>/dev/null; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge 45 ]; then
            echo "FAIL: server did not become ready" >&2
            exit 1
        fi
        sleep 1
    done
}

start
"$engine" exec "$name" sh -c \
    'curl --noproxy "*" -fsS -u "opencode:$OPENCODE_PASSWORD" http://127.0.0.1:4096/api/info >/dev/null'
actual_home=$("$engine" exec --user 10001 "$name" opencode debug paths home)
[ "$actual_home" = /data/home ] || { echo "FAIL: home is not on the volume" >&2; exit 1; }
actual_data=$("$engine" exec --user 10001 "$name" opencode debug paths data)
case "$actual_data" in
    /data/home/*) : ;;
    *) echo "FAIL: OpenCode data is not on the volume" >&2; exit 1 ;;
esac
status=$("$engine" exec "$name" curl --noproxy '*' -g -s -o /dev/null \
    -w '%{http_code}' 'http://[::1]:4096/api/info')
[ "$status" = 401 ] || { echo "FAIL: unauthenticated API returned $status" >&2; exit 1; }

# Create only an empty local session: no model credentials or inference calls.
"$engine" exec "$name" sh -c \
    'curl --noproxy "*" -g -fsS -u "opencode:$OPENCODE_PASSWORD" -H "Content-Type: application/json" -d "{\"title\":\"persistence-smoke-session\"}" http://[::1]:4096/api/session >/dev/null'

"$engine" exec --user 10001 "$name" sh -c \
    'printf persisted > /data/workspace/smoke-sentinel; printf persisted > /data/home/smoke-sentinel'
"$engine" rm -f "$name" >/dev/null
start
"$engine" exec "$name" sh -c \
    'curl --noproxy "*" -g -fsS -u "opencode:$OPENCODE_PASSWORD" http://[::1]:4096/api/session | grep -q persistence-smoke-session'
"$engine" exec --user 10001 "$name" sh -c \
    'test "$(cat /data/workspace/smoke-sentinel)" = persisted && test "$(cat /data/home/smoke-sentinel)" = persisted'
"$engine" top "$name" user args
"$engine" exec "$name" du -sh /data
"$engine" image inspect "$image" --format '{{.Size}}'
echo "PASS: password guard, port validation, authenticated API, unauthorized rejection, storage paths, and session/file persistence after container replacement"
