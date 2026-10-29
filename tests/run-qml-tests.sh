#!/bin/sh
# Runs the QML tests in the working directory (they save contact sheets there). The caller sets QML_IMPORT_PATH,
# QT_QPA_PLATFORM and the rest of the environment, and puts dbus-run-session on PATH. QMLTESTRUNNER names the runner
# (default: qmltestrunner on PATH), DBUS_SESSION_CONFIG the config of the tests' private bus, TZDIR the zone files for the clock test.
set -eu
root=${1:?usage: run-qml-tests.sh <directory holding shell/ and tests/>}
runner=${QMLTESTRUNNER:-qmltestrunner}

# A bus of its own for the DBus tests, which exists only while the tests run.
dbus-run-session ${DBUS_SESSION_CONFIG:+--config-file="$DBUS_SESSION_CONFIG"} -- \
	"$runner" -import "$root/shell" -input "$root/tests"
# Week numbers count days across a daylight saving change, which a build zone of UTC has none of.
TZ=Europe/Berlin "$runner" -import "$root/shell" -input "$root/tests/tst_clock.qml"
