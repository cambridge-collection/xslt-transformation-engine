#!/usr/bin/env sh

# Lightweight logging helpers that respect ANT_LOG_LEVEL
# These functions always succeed (even when suppressed) to avoid set -e exits.

_xte_log_level() {
  printf '%s' "${ANT_LOG_LEVEL:-default}" | tr '[:upper:]' '[:lower:]'
}

log_debug() {
  [ "$( _xte_log_level )" = "debug" ] && printf 'DEBUG: %s\n' "$*" >&2 || :
}

log_verbose() {
  lvl=$( _xte_log_level )
  { [ "$lvl" = "verbose" ] || [ "$lvl" = "debug" ]; } && printf 'VERBOSE: %s\n' "$*" >&2 || :
}

log_info() {
  case "$( _xte_log_level )" in
    default|verbose|debug)
      printf '%s\n' "$*" >&2 ;;
    *) : ;;
  esac
}

log_warn() {
  printf 'WARNING: %s\n' "$*" >&2 || :
}

log_error() {
  printf 'ERROR: %s\n' "$*" >&2 || :
}

