#!/usr/bin/env bash
# Undeclared-global scan for Scribunto modules.
#
# Live Scribunto enforces require('strict'): reading an undeclared global
# raises AT MODULE LOAD, taking down every page that transcludes the module.
# The off-wiki runner installs strict as a no-op shim, so the unit suites
# cannot catch this class — a renamed local left stale in a p._internal
# export shipped 79 green tests and would have script-errored ~75 live pages
# (caught at deploy, 2026-08-17). This scan closes that gap at compile time:
# luac5.1 lists every GETGLOBAL a chunk performs; anything outside the
# Scribunto environment allowlist is an undeclared read.
#
# SETGLOBAL is deliberately not scanned: strict permits declared writes and
# module files don't write globals; the read scan alone pins the incident
# class without false positives.
set -euo pipefail
cd "$(dirname "$0")/.."

# Globals the Scribunto sandbox provides (plus the test runner's).
ALLOW='^(mw|require|type|tostring|tonumber|pairs|ipairs|next|select|unpack|error|assert|pcall|xpcall|rawget|rawset|rawequal|rawlen|setmetatable|getmetatable|string|table|math|os|tostring|print|_G|libraryUtil|debug)$'

fail=0
while IFS= read -r -d '' f; do
	if ! luac5.1 -p "$f" 2>/dev/null; then
		echo "SYNTAX: $f"
		luac5.1 -p "$f" || true
		fail=1
		continue
	fi
	bad=$(luac5.1 -l -p "$f" 2>/dev/null | awk '/GETGLOBAL/ { gsub(/.*; /,""); print }' | sort -u | grep -Ev "$ALLOW" || true)
	if [ -n "$bad" ]; then
		echo "UNDECLARED GLOBAL in $f:"
		echo "$bad" | sed 's/^/    /'
		fail=1
	fi
done < <(find pages/module -name '*.lua' -print0)

if [ "$fail" -ne 0 ]; then
	echo 'lint-globals: FAIL (reads above would raise under live strict at module load)'
	exit 1
fi
echo 'lint-globals: OK'
