#!/bin/sh
# Checks how StartFile writes start.json in a real Quickshell: two writers, the shell and the settings app, each a
# Quickshell instance of tests/startfile/ driven over IPC. The caller puts quickshell, coreutils and diffutils on PATH
# and the repository's shell/ into QML_IMPORT_PATH, and runs it with an empty environment on a bus of its own, as the
# flake check does: env -i PATH=… QML_IMPORT_PATH=… dbus-run-session -- sh tests/startfile.sh. Every file lives in a
# temporary directory of its own.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
export HOME="$work/home" XDG_CONFIG_HOME="$work/config" XDG_RUNTIME_DIR="$work/run" QT_QPA_PLATFORM=offscreen LANG=C.UTF-8
# Each instance listens on $XDG_RUNTIME_DIR/quickshell/by-id/<10 characters>/ipc.sock, which a Unix socket path of
# at most 107 characters must hold; a longer one fails without saying why.
if [ $((${#XDG_RUNTIME_DIR} + 37)) -gt 107 ]; then
	echo "FAIL: the IPC socket path below $XDG_RUNTIME_DIR would exceed 107 characters; set a shorter TMPDIR, such as /tmp"
	rm -rf "$work"
	exit 1
fi
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
dir="$XDG_CONFIG_HOME/rekta-shell"
file="$dir/start.json"

quickshell --path "$here/startfile" > "$work/shell.log" 2>&1 &
shell=$!
quickshell --path "$here/startfile" > "$work/app.log" 2>&1 &
app=$!
early=""
followers=""
trap 'kill $shell $app $early $followers 2>/dev/null; wait; rm -rf "$work"' EXIT

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
# Around a single write only: after two, the file system may hand the freed inode out again.
inode=$(stat -c %i "$file")
[ "$(call $app unpin 0)" = true ] || fail "unpinning writes"
[ "$(stat -c %i "$file")" != "$inode" ] || fail "an atomic write replaces the file"
echo "PASS: an atomic write replaces the file"
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

printf '{"pinned": [{"id": "helium", "columns": 2}, {"id": "firefox"}]}\n' > "$work/own"
cp "$work/own" "$file"
REKTA_EARLY_PIN=org.kde.kate quickshell --path "$here/startfile" > "$work/early.log" 2>&1 &
early=$!
await $early settled true "a third writer reads the file"
[ "$(call $early earlyPin)" = false ] || fail "a change before the file's first load is refused"
cmp -s "$work/own" "$file" || fail "a change before the file's first load leaves the file as it was"
echo "PASS: a change before the file's first load is refused and leaves the file as it was"

# Two quick changes replace the file twice in a row; the second may land while a reader still reads the first or
# arms its watch anew. Many readers in one instance meet it at many such moments, round after round.
REKTA_FOLLOWERS=30 quickshell --path "$here/startfile" > "$work/followers.log" 2>&1 &
followers=$!
await $followers list "$(call $shell list)" "thirty more readers read the file"
for round in $(seq 20); do
	[ "$(call $shell pinBoth "first$round.app" "second$round.app")" = true ] || fail "two quick changes write"
	await $followers list "$(call $shell list)" "every reader shows the second of two quick changes (round $round)"
done
echo "PASS: every reader shows the second of two quick changes"
