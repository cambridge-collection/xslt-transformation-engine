#! /bin/sh

set -euo pipefail

# Set defaults for lambda for certain unset ENV vars:
set -a
: "${ANT_BUILDFILE:=bin/build.xml}"
: "${ALLOW_DELETE:=false}"
: "${EXPAND_DEFAULT_ATTRIBUTES:=false}"
ANT_LOG_LEVEL="$(printf '%s' "${ANT_LOG_LEVEL:-default}" | tr '[:upper:]' '[:lower:]')"

set +a

cp -r /opt/cdcp/bin /tmp/opt/cdcp 1>&2
cp -r /opt/cdcp/xslt /tmp/opt/cdcp 1>&2

mkdir -p /tmp/opt/cdcp/dist-final
mkdir -p /tmp/opt/cdcp/source

# Build newline-delimited includes file from TEI_FILE or CHANGED_FILES_FILE
includes_file="/tmp/opt/cdcp/includes.txt"
: > "$includes_file"

if [ -n "${CHANGED_FILES_FILE:-}" ] && [ -f "${CHANGED_FILES_FILE}" ]; then
    tr -d '\r' < "${CHANGED_FILES_FILE}" > "$includes_file"
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

/opt/ant/bin/ant ${ANT_LOG_FLAG} -buildfile /tmp/opt/cdcp/${ANT_BUILDFILE} $ANT_TARGET -Dincludes_file="$includes_file"
