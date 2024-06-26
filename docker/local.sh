#! /bin/sh

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

cp -r /opt/cdcp/bin /tmp/opt/cdcp 1>&2
cp -r /opt/cdcp/xslt /tmp/opt/cdcp 1>&2

mkdir -p /tmp/opt/cdcp/dist-final &&
	mkdir -p /tmp/opt/cdcp/source &&
	/opt/ant/bin/ant -buildfile /tmp/opt/cdcp/${ANT_BUILDFILE} $ANT_TARGET -Dfiles-to-process=$TEI_FILE
