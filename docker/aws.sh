#!/usr/bin/env bash

# The lambda cannot write to /opt/cdcp without changing user permissions and, possibly ownership
# The buildfile is currently configured to work out paths for resources relative to the buildfile's
# position within the repository. Unfortunately, the lambda cannot write to /opt/cdcp - perhaps irrespective of
# permission/owner changes. Instead, we have to work out of tmp
# Instead of going that route, copy the bin and xslt dirs into tmp and run that buildfile

set -euo pipefail

urldecode() {
	local s="${1:-}"
	# Replace '+' with space, then convert %XX to literal bytes
	s="${s//+/ }"
	printf '%b' "${s//%/\\x}"
}

function clean_source_workspace() {
	log_info "$1" &&
		rm -rf "/tmp/opt/cdcp/source" &&
		mkdir -p "/tmp/opt/cdcp/source"
}

# Set defaults for lambda for certain unset ENV vars:
set -a
: "${ANT_BUILDFILE:=bin/build.xml}"
: "${ALLOW_DELETE:=false}"
: "${EXPAND_DEFAULT_ATTRIBUTES:=false}"
ANT_LOG_LEVEL="$(printf '%s' "${ANT_LOG_LEVEL:-default}" | tr '[:upper:]' '[:lower:]')"

set +a

. "${LAMBDA_TASK_ROOT:-/var/task}/logging.sh"

log_info "Populating working dir with essentials"
cp -r /opt/cdcp/bin /tmp/opt/cdcp
cp -r /opt/cdcp/xslt /tmp/opt/cdcp

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

if [[ -v "ALLOW_DELETE" && "$ALLOW_DELETE" = true ]]; then
	DELETE_ENABLED=true
else
	DELETE_ENABLED=false
fi

function handler() {
    log_info "Parsing event notification"
    log_debug "$1"

	EVENTNAME=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].eventName')
	S3_BUCKET=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].s3.bucket.name')
	TEI_FILE=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].s3.object.key')
	
	TEI_FILE=$(urldecode "$TEI_FILE")

	if [[ -v "AWS_OUTPUT_BUCKET" && -v "ANT_TARGET" && -n "$S3_BUCKET" && -n "$TEI_FILE" ]]; then

		if [[ "$EVENTNAME" =~ ^ObjectCreated ]]; then
			log_info "Processing requested for s3://${S3_BUCKET}/${TEI_FILE}"
			clean_source_workspace "Cleaning source workspace..." &&
				log_info "Done"

			log_info "Downloading s3://${S3_BUCKET}/${TEI_FILE}"
			TARGET_PATH="/tmp/opt/cdcp/source/${TEI_FILE}"
			mkdir -p "$(dirname "${TARGET_PATH}")"
			if ! aws s3 cp --quiet "s3://${S3_BUCKET}/${TEI_FILE}" "${TARGET_PATH}" 1>&2; then
				local status=${PIPESTATUS[0]}
				log_error "Download failed for s3://${S3_BUCKET}/${TEI_FILE} (exit ${status})"
				return "$status"
			fi

			log_info "Processing ${TEI_FILE}"
			if ! (/opt/ant/bin/ant ${ANT_LOG_FLAG} -buildfile /tmp/opt/cdcp/${ANT_BUILDFILE} $ANT_TARGET -Dfiles-to-process="$TEI_FILE" -DANT_LOG_LEVEL="$ANT_LOG_LEVEL" 1>&2); then
				local status=${PIPESTATUS[0]}
				log_error "ANT target ${ANT_TARGET} failed (exit ${status})"
				return "$status"
			fi

			if ! clean_source_workspace "Cleaning up source workspace"; then
				log_error "Failed to clean source workspace"
				return 1
			fi

			log_info "OK"
		elif [[ "$EVENTNAME" =~ ^ObjectRemoved && "$DELETE_ENABLED" = true ]]; then
			log_info "Removing all outputs for: s3://${S3_BUCKET}/${TEI_FILE} from s3://${AWS_OUTPUT_BUCKET}"
			FILENAME=$(basename "$TEI_FILE" ".xml")
			CONTAINING_DIR=$(dirname "$TEI_FILE")
			# Do not execute delete, even when ALLOW_DELETE is true, to allow for testing of the consequences of the command
			if ! aws s3 rm s3://${AWS_OUTPUT_BUCKET} --dryrun --recursive --exclude "*" --include "**/${FILENAME}.${OUTPUT_EXTENSION}" --include "${FILENAME}.${OUTPUT_EXTENSION}" 1>&2; then
				local status=${PIPESTATUS[0]}
				log_error "Failed to remove outputs for s3://${S3_BUCKET}/${TEI_FILE} (exit ${status})"
				return "$status"
			fi
			log_info "OK"
		else
			log_error "Unsupported event: ${EVENTNAME}"
			return 1
		fi
	else
		if [[ ! -v "AWS_OUTPUT_BUCKET" ]]; then log_error "AWS_OUTPUT_BUCKET environment var not set"; fi
		if [[ ! -v "ANT_TARGET" ]]; then log_error "ANT_TARGET environment var not set"; fi
		if [[ -z "$S3_BUCKET" ]]; then log_error "Problem parsing event json for S3 Bucket"; fi
		if [[ -z "$TEI_FILE" ]]; then log_error "Problem parsing event json for TEI filename"; fi
		return 1
	fi
}
