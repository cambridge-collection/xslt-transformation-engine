#! /bin/sh

set -euo pipefail

set -a
: "${ANT_BUILDFILE:=bin/build.xml}"
: "${ALLOW_DELETE:=false}"
: "${EXPAND_DEFAULT_ATTRIBUTES:=false}"
ANT_LOG_LEVEL="$(printf '%s' "${ANT_LOG_LEVEL:-default}" | tr '[:upper:]' '[:lower:]')"
SOURCE_DIR="${SOURCE_DIR:=/tmp/opt/cdcp/source}"

set +a

. "${LAMBDA_TASK_ROOT:-/var/task}/logging.sh"

cp -r /opt/cdcp/bin /tmp/opt/cdcp 1>&2
cp -r /opt/cdcp/xslt /tmp/opt/cdcp 1>&2

mkdir -p /tmp/opt/cdcp/dist-final
mkdir -p "${SOURCE_DIR}"

# Build newline-delimited includes file from TEI_FILE or CHANGED_FILES_FILE
includes_file="/tmp/opt/cdcp/includes.txt"
: > "$includes_file"

cleanup() {
    [ -n "${CHANGED_FILES_FILE:-}" ] && rm -f -- "$CHANGED_FILES_FILE"
    rm -f -- "$includes_file"
}
trap 'cleanup >/dev/null 2>&1 || true' INT TERM EXIT

if [ -n "${CHANGED_FILES_FILE:-}" ] && [ -f "${CHANGED_FILES_FILE}" ]; then
    # Normalise paths: ensure entries are relative to the source directory
    tr -d '\r' < "${CHANGED_FILES_FILE}" \
      | sed -e "s|^${SOURCE_DIR}/*||" \
      > "$includes_file"
else
    printf '%s' "${TEI_FILE:-}" | tr -d '\r' > "$includes_file"
fi

ANT_LOG_FLAG=""
case "${ANT_LOG_LEVEL}" in
    warn)
        ANT_LOG_FLAG="-q"
        ;;
	default)
        ANT_LOG_FLAG=""
        ;;
    verbose)
        ANT_LOG_FLAG="-v"
        ;;
    debug)
        ANT_LOG_FLAG="-d"
        # Enable shell command tracing for debug level
        set -x
        ;;
    *)
        ANT_LOG_FLAG=""
        ;;
esac

if ! /opt/ant/bin/ant ${ANT_LOG_FLAG} -buildfile /tmp/opt/cdcp/${ANT_BUILDFILE} -lib /opt/cdcp/bin/xte/lib/antlib.xml $ANT_TARGET -Dincludes_file="$includes_file" -DANT_LOG_LEVEL="$ANT_LOG_LEVEL" 1>&2; then
    status=$?
    log_error "ANT target ${ANT_TARGET:-} failed (exit ${status})"
    exit "$status"
fi
