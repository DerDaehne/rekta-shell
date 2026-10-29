#!/bin/sh
# Installs the RPM from a clean Fedora system with Quickshell from its COPR and verifies it.
# Usage: ci-install-test.sh <directory holding the RPM>. Needs root.
set -eu
dir=${1:?usage: ci-install-test.sh <directory holding the RPM>}

# Drop --enablerepo=updates-testing together with the one in ci-build.sh.
dnf -y --enablerepo=updates-testing install dnf5-plugins
dnf -y copr enable errornointernet/quickshell
dnf -y --enablerepo=updates-testing install "$dir"/rekta-shell-[0-9]*.x86_64.rpm
rpm -V rekta-shell
rpm -q quickshell | grep -E '^quickshell-0\.3\.'
