#!/bin/sh
# Installs the RPM on a clean Fedora system with Quickshell from its COPR and verifies it.
# Usage: ci-install-test.sh <directory holding the RPM>. Needs root.
set -eu
dir=${1:?usage: ci-install-test.sh <directory holding the RPM>}

# Drop --enablerepo=updates-testing together with the one in ci-build.sh.
dnf -y --enablerepo=updates-testing install dnf5-plugins
dnf -y copr enable errornointernet/quickshell
# The build job may have seen a newer mirror state than this one: the RPM needs exactly the
# kwin-libs it was built against, which this container's mirror may not list yet. Retry on fresh metadata.
installed=false
for attempt in 1 2 3 4 5 6; do
	if dnf -y --refresh --enablerepo=updates-testing install "$dir"/rekta-shell-[0-9]*.x86_64.rpm; then
		installed=true
		break
	fi
	echo "install failed (attempt $attempt), waiting for the mirror" >&2
	sleep 60
done
$installed
rpm -V rekta-shell
rpm -q quickshell | grep -E '^quickshell-0\.3\.'
# The effects load only in the KWin they were built against.
rpm -q --requires rekta-shell | grep -Fx "kwin-libs(x86-64) = $(rpm -q --qf '%{version}' kwin-libs)"
