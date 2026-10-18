#!/bin/sh
set -eu

# Fail closed before binding any network port. Never print the password.
: "${OPENCODE_PASSWORD:?Set OPENCODE_PASSWORD in Railway service variables}"

case "${PORT:-4096}" in
    ''|*[!0-9]*) echo "PORT must be a number" >&2; exit 1 ;;
esac
if [ "${PORT:-4096}" -lt 1 ] || [ "${PORT:-4096}" -gt 65535 ]; then
    echo "PORT must be between 1 and 65535" >&2
    exit 1
fi

# A newly attached Railway volume is root-owned. Only change the dedicated
# directories themselves; do not recursively walk existing project files.
mkdir -p /data/home /data/workspace
chown opencode:opencode /data/home /data/workspace

exec gosu opencode sh -c '
    umask 077
    cd /data/workspace
    exec opencode serve --hostname :: --port "${PORT:-4096}"
'
