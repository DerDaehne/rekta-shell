#!/bin/sh
# Fails unless the tag is "v" plus the version of the spec. Usage: ci-check-tag.sh <tag>
set -eu
tag=${1:?usage: ci-check-tag.sh <tag>}
version=$(sed -n 's/^Version:[[:space:]]*//p' "$(dirname "$0")/rekta-shell.spec")
if [ "$tag" != "v$version" ]; then
	echo "tag $tag does not match the spec version v$version" >&2
	exit 1
fi
