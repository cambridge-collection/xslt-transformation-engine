#!/usr/bin/env sh

set -eu

# Normalise XTE_MODE to lowercase for comparison
MODE="$(printf '%s' "${XTE_MODE:-}" | tr '[:upper:]' '[:lower:]')"

if [ "$MODE" = "standalone" ]; then
  echo "Delegating to /var/task/standalone.sh" >&1
  exec /var/task/standalone.sh
else
    echo "Delegating to Lambda entrypoint" >&1
  exec /lambda-entrypoint.sh "$@"
fi

