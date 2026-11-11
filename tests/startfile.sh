#!/bin/sh
# Checks how StartFile writes start.json in a real Quickshell: two writers, the shell and the settings app, each a
# Quickshell instance of tests/startfile/ driven over IPC. The caller puts quickshell and coreutils on PATH and the
# repository's shell/ into QML_IMPORT_PATH; every file lives in a temporary directory of its own.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
export HOME="$work/home" XDG_CONFIG_HOME="$work/config" XDG_RUNTIME_DIR="$work/run" QT_QPA_PLATFORM=offscreen LANG=C.UTF-8
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
dir="$XDG_CONFIG_HOME/rekta-shell"
file="$dir/start.json"

quickshell --path "$here/startfile" > "$work/shell.log" 2>&1 &
shell=$!
quickshell --path "$here/startfile" > "$work/app.log" 2>&1 &
app=$!
trap 'kill $shell $app 2>/dev/null; wait; rm -rf "$work"' EXIT

call() {
	pid=$1
	shift
	quickshell ipc --pid "$pid" call start "$@"
}

fail() {
	echo "FAIL: $1"
	cat "$work/shell.log" "$work/app.log"
	exit 1
}

# Waits up to ten seconds for `call <pid> <function>` to print `expected`.
await() {
	for _ in $(seq 100); do
		[ "$(call "$1" "$2" 2>/dev/null)" = "$3" ] && return 0
		sleep 0.1
	done
	fail "$4 (instance $1, $2 printed $(call "$1" "$2" 2>&1))"
}

ids() {
	grep -o '"id": "[^"]*"' "$file" | cut -d '"' -f 4 | tr '\n' ' '
}

await $shell settled true "the shell reads a start.json that does not exist"
await $app settled true "the app reads a start.json that does not exist"

[ "$(call $shell pin org.kde.kate)" = true ] || fail "pinning writes"
[ -f "$file" ] || fail "the first write creates the missing directory"
[ "$(ids)" = "systemsettings org.kde.dolphin org.kde.konsole org.kde.kate " ] || fail "the first write keeps the defaults: $(ids)"
echo "PASS: the first write creates the missing directory and keeps the defaults"

await $app list '[{"id":"systemsettings"},{"id":"org.kde.dolphin"},{"id":"org.kde.konsole"},{"id":"org.kde.kate","columns":1,"rows":1}]' \
	"a change from the other writer arrives live"
echo "PASS: a change from the other writer arrives live"

[ "$(call $shell pinBoth first.app second.app)" = true ] || fail "two quick changes write"
[ "$(ids)" = "systemsettings org.kde.dolphin org.kde.konsole org.kde.kate first.app second.app " ] ||
	fail "two quick changes build on each other: $(ids)"
echo "PASS: two quick changes build on each other"

await $app list "$(call $shell list)" "the app follows the shell's changes"
[ "$(call $app unpin 0)" = true ] || fail "unpinning writes"
await $shell list '[{"id":"org.kde.dolphin"},{"id":"org.kde.konsole"},{"id":"org.kde.kate","columns":1,"rows":1},{"id":"first.app","columns":1,"rows":1},{"id":"second.app","columns":1,"rows":1}]' \
	"the last writer wins and the other follows"
echo "PASS: two writers, the last one wins and the other follows live"

[ "$(ls -A "$dir")" = start.json ] || fail "an atomic write leaves no temporary file: $(ls -A "$dir")"
echo "PASS: an atomic write leaves no temporary file"

printf '{ "pinned": "broken' > "$work/broken"
cp "$work/broken" "$file"
await $shell fault broken "a broken file is reported"
[ "$(call $shell list)" = null ] || fail "a broken file shows the defaults"
[ "$(call $shell pin org.kde.kate)" = false ] || fail "nothing writes over a broken file"
await $app fault broken "the app sees the broken file too"
[ "$(call $app unpin 0)" = false ] || fail "the app writes nothing over a broken file"
cmp -s "$work/broken" "$file" || fail "a broken file stays as it was"
grep -q "start.json holds no JSON object" "$work/shell.log" || fail "a broken file is reported in the log"
echo "PASS: a broken file stays untouched, shows the defaults and is reported in the log"
