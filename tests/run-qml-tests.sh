#!/bin/sh
# Runs the QML tests in the working directory (they save contact sheets there), each file in a runner and on a bus of
# its own, at most six files at once. Given test file names, it runs only those. The caller sets QML_IMPORT_PATH,
# QT_PLUGIN_PATH, FONTCONFIG_FILE, QT_QUICK_BACKEND, HOME and LANG, and puts dbus-run-session on PATH; no other variable
# reaches the tests, so neither the desktop's bus, display nor QML modules can; they run offscreen and find no system bus.
# QMLTESTRUNNER names the runner (default: qmltestrunner on PATH), DBUS_SESSION_CONFIG the config of the tests' private
# bus, TZDIR the zone files for the clock test, NIX_BUILD_CORES the cores to use (default and 0: all).
set -eu
root=${1:?usage: run-qml-tests.sh <directory holding shell/ and tests/> [tst_<name>.qml ...]}
shift
export root runner="${QMLTESTRUNNER:-qmltestrunner}" logs="$(mktemp -d)"
trap 'rm -rf "$logs"' EXIT
cores=${NIX_BUILD_CORES:-0}
[ "$cores" -gt 0 ] || cores=$(nproc)
[ "$cores" -le 6 ] || cores=6

# One job per line: the log's name, the test file, then the job's own environment.
list_jobs() {
	if [ $# -eq 0 ]; then
		set -- "$root"/tests/tst_*.qml
		# Week numbers count days across a daylight saving change, which a build zone of UTC has none of.
		echo "tst_clock-berlin tst_clock.qml TZ=Europe/Berlin"
		# A picture icon's own size counts in logical px on a scaled display too.
		echo "tst_pictureicon-scaled tst_pictureicon.qml QT_SCALE_FACTOR=2"
	fi
	for file; do
		file=${file##*/}
		echo "${file%.qml} $file"
	done
}

# A bus of its own for each file, which exists only while it runs. The stand-ins take the place of the modules from
# Quickshell and Plasma that a service imports.
list_jobs "$@" | xargs -L 1 -P "$cores" sh -c '
	name=$1 file=$2
	shift 2
	env -i PATH="$PATH" ${HOME+"HOME=$HOME"} ${LANG+"LANG=$LANG"} ${TMPDIR+"TMPDIR=$TMPDIR"} ${TZDIR+"TZDIR=$TZDIR"} \
		${QML_IMPORT_PATH+"QML_IMPORT_PATH=$QML_IMPORT_PATH"} ${QT_PLUGIN_PATH+"QT_PLUGIN_PATH=$QT_PLUGIN_PATH"} \
		${FONTCONFIG_FILE+"FONTCONFIG_FILE=$FONTCONFIG_FILE"} ${QT_QUICK_BACKEND+"QT_QUICK_BACKEND=$QT_QUICK_BACKEND"} \
		QT_QPA_PLATFORM=offscreen DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent/system_bus_socket "$@" \
		dbus-run-session ${DBUS_SESSION_CONFIG:+--config-file="$DBUS_SESSION_CONFIG"} -- \
		"$runner" -import "$root/shell" -import "$root/tests/stand-ins" -input "$root/tests/$file" \
		> "$logs/$name.log" 2>&1 || : > "$logs/$name.failed"
' sh

failures=""
for log in "$logs"/*.log; do
	name=$(basename "$log" .log)
	if [ -e "$logs/$name.failed" ] || ! grep -q '^Totals:' "$log"; then
		failures="$failures $name"
		echo "=== $name failed:"
		cat "$log"
	else
		echo "$name: $(grep '^Totals:' "$log")"
	fi
done
awk '/^Totals:/ { passed += $2; failed += $4; skipped += $6; blacklisted += $8 }
	END { printf "Totals: %d passed, %d failed, %d skipped, %d blacklisted\n", passed, failed, skipped, blacklisted }' "$logs"/*.log
[ -n "$failures" ] || exit 0
for name in $failures; do
	{ grep '^FAIL!' "$logs/$name.log" || echo "ended without a result"; } | sed "s/^/$name: /"
done
exit 1
