#! /bin/sh


# Set defaults for lambda for certain unset ENV vars:
set -a
: "${ANT_BUILDFILE:=bin/build.xml}"
: "${ALLOW_DELETE:=false}"
: "${EXPAND_DEFAULT_ATTRIBUTES:=false}"
set +a

cp -r /opt/cdcp/bin /tmp/opt/cdcp 1>&2
cp -r /opt/cdcp/xslt /tmp/opt/cdcp 1>&2

mkdir -p /tmp/opt/cdcp/dist-final &&
	mkdir -p /tmp/opt/cdcp/source &&
	/opt/ant/bin/ant -buildfile /tmp/opt/cdcp/${ANT_BUILDFILE} $ANT_TARGET -Dfiles-to-process=$TEI_FILE
