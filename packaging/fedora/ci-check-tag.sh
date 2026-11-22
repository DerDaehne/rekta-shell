#!/bin/sh
# Fails unless the tag is "v" plus the version of the spec in tag form. Usage: ci-check-tag.sh <tag>
set -eu
tag=${1:?usage: ci-check-tag.sh <tag>}
version=$(sh "$(dirname "$0")/../version.sh" tag)
if [ "$tag" != "v$version" ]; then
	echo "tag $tag does not match the spec version v$version" >&2
	exit 1
fi
