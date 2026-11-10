#!/bin/sh
# Runs the QML tests in the working directory, each file in a runner and on a bus of its own, at most six files at once.
# Given test file names, it runs only those. The caller sets QML_IMPORT_PATH, QT_PLUGIN_PATH, FONTCONFIG_FILE,
# QT_QUICK_BACKEND, HOME and LANG, and puts dbus-run-session on PATH; no other variable reaches the tests, so neither the
# desktop's bus, display nor QML modules can; they run offscreen and find no system bus. QMLTESTRUNNER names the runner
# (default: qmltestrunner on PATH), DBUS_SESSION_CONFIG the config of the tests' private bus, TZDIR the zone files for the
# clock test, NIX_BUILD_CORES the cores to use (default and 0: all). CONTACT_SHEETS=1 also renders the contact sheets
# into the working directory; without it their tests skip.
set -eu
root=${1:?usage: run-qml-tests.sh <directory holding shell/ and tests/> [tst_<name>.qml ...]}
shift
# A file that has not ended after five minutes hangs: the slowest takes well under one.
export root runner="${QMLTESTRUNNER:-qmltestrunner}" logs="$(mktemp -d)" limit=300 sheets="${CONTACT_SHEETS:+contact-sheets}"
trap 'rm -rf "$logs"' EXIT
cores=${NIX_BUILD_CORES:-0}
[ "$cores" -gt 0 ] || cores=$(nproc)
[ "$cores" -le 6 ] || cores=6

# One job per line: a test file, then the name and environment of a second run of it. The second run follows the
# first, so the contact sheets it saves over the first one's are always its own.
list_jobs() {
	if [ $# -gt 0 ]; then
		for file; do echo "${file##*/}"; done
		return
	fi
	for file in "$root"/tests/tst_*.qml; do
		case ${file##*/} in
		# Week numbers count days across a daylight saving change, which a build zone of UTC has none of.
		tst_clock.qml) echo "tst_clock.qml berlin TZ=Europe/Berlin" ;;
		# A picture icon's own size counts in logical px on a scaled display too.
		tst_pictureicon.qml) echo "tst_pictureicon.qml scaled QT_SCALE_FACTOR=2" ;;
		*) echo "${file##*/}" ;;
		esac
	done
}

# A bus of its own for each file, which exists only while it runs. The stand-ins take the place of the modules from
# Quickshell and Plasma that a service imports. Each run prints its result as it ends.
list_jobs "$@" | xargs -L 1 -P "$cores" sh -c '
	run() {
		name=$1 file=$2
		shift 2
		status=0
		env -i PATH="$PATH" ${HOME+"HOME=$HOME"} ${LANG+"LANG=$LANG"} ${TMPDIR+"TMPDIR=$TMPDIR"} ${TZDIR+"TZDIR=$TZDIR"} \
			${QML_IMPORT_PATH+"QML_IMPORT_PATH=$QML_IMPORT_PATH"} ${QT_PLUGIN_PATH+"QT_PLUGIN_PATH=$QT_PLUGIN_PATH"} \
			${FONTCONFIG_FILE+"FONTCONFIG_FILE=$FONTCONFIG_FILE"} ${QT_QUICK_BACKEND+"QT_QUICK_BACKEND=$QT_QUICK_BACKEND"} \
			QT_QPA_PLATFORM=offscreen DBUS_SYSTEM_BUS_ADDRESS=unix:path=/nonexistent/system_bus_socket "$@" \
			dbus-run-session ${DBUS_SESSION_CONFIG:+--config-file="$DBUS_SESSION_CONFIG"} -- timeout "$limit" \
			"$runner" ${sheets:+-file-selector "$sheets"} -import "$root/shell" -import "$root/tests/stand-ins" \
			-input "$root/tests/$file" \
			> "$logs/$name.log" 2>&1 || status=$?
		[ "$status" -ne 124 ] || echo "timed out after $limit s" >> "$logs/$name.log"
		[ "$status" -eq 0 ] || : > "$logs/$name.failed"
		echo "$name: $(grep "^Totals:" "$logs/$name.log" || tail -n 1 "$logs/$name.log")"
	}
	run "${1%.qml}" "$1"
	[ $# -lt 3 ] || run "${1%.qml}-$2" "$1" "$3"
' sh

failures=""
for log in "$logs"/*.log; do
	name=$(basename "$log" .log)
	if [ -e "$logs/$name.failed" ] || ! grep -q '^Totals:' "$log"; then
		failures="$failures $name"
		echo "=== $name failed:"
		cat "$log"
	fi
done
awk '/^Totals:/ { passed += $2; failed += $4; skipped += $6; blacklisted += $8 }
	END { printf "Totals: %d passed, %d failed, %d skipped, %d blacklisted\n", passed, failed, skipped, blacklisted }' "$logs"/*.log
[ -n "$failures" ] || exit 0
for name in $failures; do
	{ grep -e '^FAIL!' -e '^timed out' "$logs/$name.log" || echo "ended without a result"; } | sed "s/^/$name: /"
done
exit 1
