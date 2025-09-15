#!/usr/bin/env bash

set -euo pipefail
echo "Running copy-wellformed" >&1
echo "${@}" >&1

SOURCE_DIR=${1}
OUT_DIR=${2}

[[ -z "$SOURCE_DIR" || -z "$OUT_DIR" ]] && { echo "ERROR: --source-dir and --out-dir are required" >&2; usage; exit 2; }

mkdir -p "${OUT_DIR}"

find "${SOURCE_DIR}" -type f -name '*.xml' -print0 \
| while IFS= read -r -d '' file; do
  if xmllint --noout "${file}" 2>/dev/null; then
    rel_path="${file#${SOURCE_DIR}/}"
    target="$OUT_DIR/$rel_path"
    mkdir -p "$(dirname "${target}")"
    cp -- "${file}" "${target}"
    echo "Copied: ${file} to ${target}"
  else
    echo "ERROR: ${file} is not valid XML" >&2
  fi
done
