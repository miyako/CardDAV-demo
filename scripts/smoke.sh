#!/bin/sh
# Headless acceptance for this demo.
#
# Stages the pinned CardDAV component, runs Demo_HeadlessSmoke with tool4d and
# asserts the report with scripts/verify.py. No form is opened, no server is
# contacted and no credential is read.
#
#   scripts/smoke.sh [report.json]
#
# tool4d is looked up as $TOOL4D, then /Applications/4D */tool4d.app, then
# /Applications/tool4d.app.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
report=${1:-/tmp/CardDAV-demo-smoke.json}

python3 "$root/scripts/fetch_dependency.py" >/dev/null

if [ -z "${TOOL4D:-}" ]; then
	for candidate in /Applications/4D\ *"/tool4d.app/Contents/MacOS/tool4d" /Applications/tool4d.app/Contents/MacOS/tool4d; do
		if [ -x "$candidate" ]; then
			TOOL4D=$candidate
			break
		fi
	done
fi
if [ -z "${TOOL4D:-}" ] || [ ! -x "${TOOL4D:-}" ]; then
	echo "tool4d not found; set TOOL4D=/path/to/tool4d" >&2
	exit 2
fi

project="$root/Project/CardDAV-demo.4DProject"
if [ ! -f "$project" ]; then
	echo "no project at $project" >&2
	exit 2
fi

rm -f "$report"
"$TOOL4D" --project "$project" --dataless --skip-onstartup \
	--startup-method=Demo_HeadlessSmoke \
	--user-param "{\"out\":\"$report\"}" >/dev/null 2>&1 || true

if [ ! -s "$report" ]; then
	echo "the smoke method wrote no report at $report" >&2
	echo "check that the CardDAV component is staged (docs/FINDINGS.md)" >&2
	exit 1
fi

python3 "$root/scripts/verify.py" "$report"
