#!/usr/bin/env sh

set -eu

. "${LAMBDA_TASK_ROOT:-/var/task}/logging.sh"

ENVIRONMENT_MODE="$(printf '%s' "${ENVIRONMENT:-aws}" | tr '[:upper:]' '[:lower:]')"

if [ "$ENVIRONMENT_MODE" = "standalone" ]; then
  log_info "Delegating to /var/task/standalone.sh"
  exec /var/task/standalone.sh
else
  if [ "$ENVIRONMENT_MODE" != "aws" ]; then
    log_warn "Unrecognised ENVIRONMENT: '$ENVIRONMENT_MODE'; defaulting to aws"
  fi
  log_info "Delegating to Lambda entrypoint"
  exec /lambda-entrypoint.sh "$@"
fi
