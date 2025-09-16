#!/usr/bin/env sh

set -eu

. "${LAMBDA_TASK_ROOT:-/var/task}/logging.sh"

MODE="$(printf '%s' "${XTE_MODE:-}" | tr '[:upper:]' '[:lower:]')"

if [ "$MODE" = "standalone" ]; then
  log_info "Delegating to /var/task/standalone.sh"
  exec /var/task/standalone.sh
else
  log_info "Delegating to Lambda entrypoint"
  exec /lambda-entrypoint.sh "$@"
fi
