#!/usr/bin/env bash
# Prepares a release on main: bumps the spec, commits, scans, tags. It never pushes.
# Usage: scripts/release.sh <version> <notes-file> [--dry-run]    (needs git and gh)
#
# The notes file becomes the annotated tag's message and, through the workflow, the
# GitHub release notes. English, for users: a few bullets per area, ticket ids only as
# "(#id)" like in commit subjects, no board internals.
#
#   rekta-shell 0.1.1
#
#   Shell
#   - The Start folds in from the bottom (#<id>)
#
#   Packaging
#   - The RPM requires the exact kwin-libs it was built against (#<id>)
set -euo pipefail

spec=packaging/fedora/rekta-shell.spec

die() {
	echo "release: $*" >&2
	exit 1
}

check_clean_main() {
	[ -z "$(git status --porcelain)" ] || die "the working tree is not clean"
	[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "not on main"
	git fetch --quiet origin main
	[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main differs from origin/main"
}

check_ci_green() {
	local sha not_green
	sha=$(git rev-parse HEAD)
	not_green=$(gh run list --commit "$sha" --limit 50 --json name,status,conclusion \
		--jq '.[] | select(.status != "completed" or .conclusion != "success") | .name')
	[ -z "$not_green" ] || die "workflows of $sha are not green: $not_green"
	[ -n "$(gh run list --commit "$sha" --limit 1 --json name --jq '.[].name')" ] || die "no workflow ran for $sha"
}

bump_spec() {
	local version=$1 entry
	entry="* $(LC_ALL=C date '+%a %b %d %Y') rekta-shell maintainers - $version-1"
	sed -i -e "s/^\(Version:[[:space:]]*\).*/\1$version/" \
		-e "/^%changelog/a $entry\n- Release $version" "$spec"
}

commit_and_tag() {
	local version=$1 notes=$2
	git add "$spec"
	git commit --quiet -m "chore: release $version" -m "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
	scripts/scan-secrets.sh
	sh packaging/fedora/ci-check-tag.sh "v$version"
	git tag -a "v$version" -F "$notes"
}

main() {
	local dry_run=0 version notes
	version=${1:?usage: release.sh <version> <notes-file> [--dry-run]}
	notes=${2:?usage: release.sh <version> <notes-file> [--dry-run]}
	[ "${3:-}" != --dry-run ] || dry_run=1
	[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like 0.1.1"
	[ -s "$notes" ] || die "notes file $notes is missing or empty"
	cd "$(git rev-parse --show-toplevel)"
	git rev-parse -q --verify "refs/tags/v$version" >/dev/null && die "tag v$version exists"
	check_clean_main
	check_ci_green
	if [ "$dry_run" = 1 ]; then
		echo "dry run: would bump $spec to $version, commit 'chore: release $version', scan, tag v$version"
		return
	fi
	bump_spec "$version"
	commit_and_tag "$version" "$notes"
	echo "tagged v$version. To publish:"
	echo "  git push origin main"
	echo "  git push origin v$version"
}

main "$@"
