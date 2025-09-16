#!/usr/bin/env bash

# Hook script that runs after all Ant processing just before copying to the final destination.

set -euo pipefail

# Source shared logging helpers
. "${LAMBDA_TASK_ROOT:-/var/task}/logging.sh"

# Preserve original arguments for debug output when SOURCE_DIR == OUT_DIR
ORIG_ARGS=("$@")

usage() {
  cat >&2 <<'USAGE'
Usage: post.sh --source-dir <dir> [ --includes-file <path> | --pattern <glob> ] --out-dir <dir>

Selects files from --source-dir using either an includes file (newline-delimited globs)
or a glob pattern, then copies the matched files into --out-dir preserving directory
structure relative to --source-dir.
USAGE
}

SOURCE_DIR=""
OUT_DIR=""
MODE="auto"         # one of: auto, includes-file, pattern
VALUE=""            # path or pattern depending on MODE

log_info "Running post.sh"
log_debug "$@"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-dir)
      SOURCE_DIR="${2:-}"; shift 2 ;;
    --out-dir)
      OUT_DIR="${2:-}"; shift 2 ;;
    --includes-file|-f)
      MODE="includes-file"; VALUE="${2:-}"; shift 2 ;;
    --pattern|-p)
      MODE="pattern"; VALUE="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      # Back-compat: allow a single positional includes file or pattern
      if [[ -z "$VALUE" ]]; then
        if [[ -f "$1" ]]; then MODE="includes-file"; VALUE="$1"; else MODE="pattern"; VALUE="$1"; fi
        shift
      else
        log_error "Unknown argument: $1"; usage; exit 2
      fi
      ;;
  esac
done

[[ -z "$SOURCE_DIR" || -z "$OUT_DIR" ]] && { log_error "--source-dir and --out-dir are required"; usage; exit 2; }

if [[ "$SOURCE_DIR" == "$OUT_DIR" ]]; then
  log_error "--source-dir and --out-dir cannot have the same value"
  exit 0
fi

mkdir -p "$OUT_DIR"

get_patterns() {
  case "$MODE" in
    includes-file)
      [[ -f "$VALUE" ]] || { log_error "includes file not found: $VALUE"; exit 3; }
      tr -d '\r' < "$VALUE"
      ;;
    pattern|auto)
      printf '%s' "$VALUE"
      ;;
    *) log_error "unknown mode: $MODE"; exit 3 ;;
  esac
}

copy_matches() {
  local count=0
  shopt -s nullglob globstar
  (
    cd "$SOURCE_DIR" 2>/dev/null || { log_warn "source dir not found: $SOURCE_DIR"; exit 0; }
    while IFS= read -r pat || [[ -n "$pat" ]]; do
      pat="${pat//$'\r'/}"
      [[ -z "$pat" ]] && continue
      mapfile -t matches < <(compgen -G -- "$pat")
      if [[ ${#matches[@]} -eq 0 ]]; then
        if [[ -f "$pat" ]]; then matches=("$pat"); fi
      fi
      for rel in "${matches[@]}"; do
        local src="$SOURCE_DIR/$rel"
        local dst="$OUT_DIR/$rel"
        mkdir -p "$(dirname "$dst")"
        cp -p "$src" "$dst"
        log_info "$rel"
        ((count++))
      done
    done < <(get_patterns)
    log_info "post.hook copied $count file(s)"
  )
  shopt -u nullglob globstar
}

copy_matches
