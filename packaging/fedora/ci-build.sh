#!/bin/sh
# Builds the RPM and SRPM of the checkout in the current directory inside a Fedora system and
# lints them. Usage: ci-build.sh <output directory>. Needs root and a git checkout.
set -eu
out=${1:?usage: ci-build.sh <output directory>}
spec=packaging/fedora/rekta-shell.spec
version=$(sed -n 's/^Version:[[:space:]]*//p' "$spec")

# Plasma 6.8 is in updates-testing only. Drop --enablerepo=updates-testing once the
# targeted Fedora release ships Plasma 6.8 as a stable update.
dnf -y --enablerepo=updates-testing upgrade
dnf -y --enablerepo=updates-testing install rpm-build rpmlint dnf5-plugins git
dnf -y --enablerepo=updates-testing builddep "$spec"

git config --global --add safe.directory "$PWD"
top=$(mktemp -d)
mkdir -p "$top/SOURCES"
git archive --prefix="rekta-shell-$version/" -o "$top/SOURCES/rekta-shell-$version.tar.gz" HEAD
rpmbuild -ba --define "_topdir $top" "$spec"

mkdir -p "$out"
cp "$top"/RPMS/*/rekta-shell-[0-9]*.rpm "$top"/SRPMS/*.src.rpm "$out"
rpmlint "$out"/*.rpm
