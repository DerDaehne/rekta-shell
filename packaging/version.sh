#!/bin/sh
# Prints the version of the spec in one form. Usage: version.sh base|rpm|tag|safe [spec]
#   base  0.1.5                           the SemVer base, which only the maintainer raises
#   rpm   0.1.5^20261122.1830gitabc1234   the spec's Version: a base, or a base with Fedora's snapshot caret
#   tag   0.1.5+20261122.1830.abc1234     the same as SemVer build metadata; git tags cannot hold "^"
#   safe  0.1.5.20261122.1830gitabc1234   the rpm form with every character outside [A-Za-z0-9._-] a ".", for build directories and tarballs
set -eu
form=${1:?usage: version.sh base|rpm|tag|safe [spec]}
spec=${2:-$(dirname "$0")/fedora/rekta-shell.spec}
rpm=$(sed -n 's/^Version:[[:space:]]*//p' "$spec")
case $form in
base) echo "${rpm%%^*}" ;;
rpm) echo "$rpm" ;;
safe) echo "$rpm" | sed 's/[^A-Za-z0-9._-]/./g' ;;
tag) echo "$rpm" | sed -e 's/\^/+/' -e 's/git/./' ;;
*) echo "unknown form $form" >&2; exit 1 ;;
esac
