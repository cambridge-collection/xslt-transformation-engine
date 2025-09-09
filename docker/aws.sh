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
	echo "$1" 1>&2 &&
		rm -rf "/tmp/opt/cdcp/source" 1>&2 &&
		mkdir -p "/tmp/opt/cdcp/source" 1>&2
}

# Set defaults for lambda for certain unset ENV vars:
set -a
: "${ANT_BUILDFILE:=bin/build.xml}"
: "${ALLOW_DELETE:=false}"
: "${EXPAND_DEFAULT_ATTRIBUTES:=false}"
ANT_LOG_LEVEL="$(printf '%s' "${ANT_LOG_LEVEL:-default}" | tr '[:upper:]' '[:lower:]')"

set +a

echo "Populating working dir with essentials" 1>&2
cp -r /opt/cdcp/bin /tmp/opt/cdcp 1>&2
cp -r /opt/cdcp/xslt /tmp/opt/cdcp 1>&2

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
	echo "Parsing event notification" 1>&2
	echo "$1" 1>&2

	EVENTNAME=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].eventName') 1>&2
	S3_BUCKET=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].s3.bucket.name') 1>&2
	TEI_FILE=$(echo "$1" | jq -r '.Records[].body' | jq -r '.Records[].s3.object.key') 1>&2
	
	TEI_FILE=$(urldecode "$TEI_FILE")

	if [[ -v "AWS_OUTPUT_BUCKET" && -v "ANT_TARGET" && -n "$S3_BUCKET" && -n "$TEI_FILE" ]]; then

		if [[ "$EVENTNAME" =~ ^ObjectCreated ]]; then

			echo "Processing requested for s3://${S3_BUCKET}/${TEI_FILE}" 1>&2
			clean_source_workspace "Cleaning source workspace..." &&
				echo "Done" 1>&2

			
	echo "Downloading s3://${S3_BUCKET}/${TEI_FILE}" 1>&2
	TARGET_PATH="/tmp/opt/cdcp/source/${TEI_FILE}"
	mkdir -p "$(dirname "${TARGET_PATH}")" 1>&2
	aws s3 cp --quiet "s3://${S3_BUCKET}/${TEI_FILE}" "${TARGET_PATH}" 1>&2 &&
				echo "Processing ${TEI_FILE}" 1>&2
			(/opt/ant/bin/ant ${ANT_LOG_FLAG} -buildfile /tmp/opt/cdcp/${ANT_BUILDFILE} $ANT_TARGET -Dfiles-to-process="$TEI_FILE") 1>&2 &&
				clean_source_workspace "Cleaning up source workspace" &&
				echo "OK" 1>&2
		elif [[ "$EVENTNAME" =~ ^ObjectRemoved && "$DELETE_ENABLED" = true ]]; then
			echo "Removing all outputs for: s3://${S3_BUCKET}/${TEI_FILE} from s3://${AWS_OUTPUT_BUCKET}" 1>&2
			FILENAME=$(basename "$TEI_FILE" ".xml")
			CONTAINING_DIR=$(dirname "$TEI_FILE")
			# Do not execute delete, even when ALLOW_DELETE is true, to allow for testing of the consequences of the command
			aws s3 rm s3://${AWS_OUTPUT_BUCKET} --dryrun --recursive --exclude "*" --include "**/${FILENAME}.${OUTPUT_EXTENSION}" --include "${FILENAME}.${OUTPUT_EXTENSION}" 1>&2 &&
				echo "OK" 1>&2
		else
			echo "ERROR: Unsupported event: ${EVENTNAME}" 1>&2
			return 1
		fi
	else
		if [[ ! -v "AWS_OUTPUT_BUCKET" ]]; then echo "ERROR: AWS_OUTPUT_BUCKET environment var not set" 1>&2; fi
		if [[ ! -v "ANT_TARGET" ]]; then echo "ERROR: ANT_TARGET environment var not set" 1>&2; fi
		if [[ -z "$S3_BUCKET" ]]; then echo "ERROR: Problem parsing event json for S3 Bucket" 1>&2; fi
		if [[ -z "$TEI_FILE" ]]; then echo "ERROR: Problem parsing event json for TEI filename" 1>&2; fi
		return 1
	fi
}
