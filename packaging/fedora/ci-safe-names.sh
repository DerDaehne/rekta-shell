#!/bin/sh
# GitHub renames release assets whose names hold special characters, such as the "^" of a snapshot version, which
# would leave SHA256SUMS naming files that do not exist. Renames every RPM in the directory to a safe name.
# dnf reads the version from the RPM's header, so the file name does not matter for installing.
# Usage: ci-safe-names.sh <directory>
set -eu
cd "${1:?usage: ci-safe-names.sh <directory>}"
for f in *.rpm; do
	safe=$(printf '%s' "$f" | sed 's/[^A-Za-z0-9._-]/./g')
	[ "$f" = "$safe" ] || mv -- "$f" "$safe"
done
