#!/usr/bin/env bash
# Prepares a release on main: bumps the spec, commits, scans, tags. It never pushes.
# Usage: scripts/release.sh <version> <notes-file> [--dry-run]    (needs git and gh)
#        scripts/release.sh --help
# Environment: RELEASE_TRAILER, a line appended to the release commit message (e.g. a Co-Authored-By trailer).
#
# The notes file becomes the annotated tag's message (kept verbatim, "#" headings included) and,
# through the workflow, the public GitHub release notes. English, for users: a few bullets per
# area, ticket ids only as "(#<id>)" like in commit subjects, no board internals. The file is scanned
# for secrets and local paths before anything is written. Template:
#
#   rekta-shell 0.1.1
#
#   ## Shell
#   - The Start folds in from the bottom (#<id>)
#
#   ## Packaging
#   - The RPM requires the exact kwin-libs it was built against (#<id>)
set -euo pipefail

spec=packaging/fedora/rekta-shell.spec
required_workflows="privacy nix rpm"
committed=0

die() {
	echo "release: $*" >&2
	exit 1
}

usage() {
	sed -n '2,/^set -euo/p' "$0" | sed -e '/^set -euo/d' -e 's/^# \{0,1\}//'
}

absolute() {
	local dir
	dir=$(cd "$(dirname "$1")" 2>/dev/null && pwd) || die "no such directory for $1"
	echo "$dir/$(basename "$1")"
}

check_clean_main() {
	[ -z "$(git status --porcelain)" ] || die "the working tree is not clean"
	[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "not on main"
	git fetch --quiet origin main
	[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main differs from origin/main"
}

check_ci_green() {
	local sha runs name
	sha=$(git rev-parse HEAD)
	runs=$(gh run list --commit "$sha" --limit 50 --json name,status,conclusion \
		--jq '.[] | "\(.name) \(.status) \(.conclusion)"')
	! grep -qv ' completed success$' <<<"$runs" || die "workflows of $sha are not all green: $runs"
	for name in $required_workflows; do
		grep -q "^$name completed success$" <<<"$runs" || die "workflow $name has no green run for $sha"
	done
}

bump_spec() {
	local version=$1 entry
	entry="* $(LC_ALL=C date '+%a %b %d %Y') rekta-shell maintainers - $version-1"
	sed -i -e "s/^\(Version:[[:space:]]*\).*/\1$version/" \
		-e "/^%changelog/a $entry\n- Release $version" "$spec"
}

commit_release() {
	local version=$1
	git add "$spec"
	git commit --quiet -m "chore: release $version" ${RELEASE_TRAILER:+-m "$RELEASE_TRAILER"}
	committed=1
}

tag_release() {
	local version=$1 notes=$2
	scripts/scan-secrets.sh --notes "$notes"
	sh packaging/fedora/ci-check-tag.sh "v$version"
	git tag -a --cleanup=verbatim "v$version" -F "$notes"
}

print_undo() {
	[ "$committed" = 1 ] || return 0
	echo "release failed after the commit. Undo it yourself:" >&2
	echo "  git reset --soft HEAD~1 && git restore --staged $spec && git restore $spec" >&2
	echo "  git tag -d v$1   # only if the tag was made" >&2
}

main() {
	local dry_run=0 version=${1:-} notes=${2:-}
	[ "$version" != --help ] || { usage; return; }
	[ -n "$version" ] && [ -n "$notes" ] || die "usage: release.sh <version> <notes-file> [--dry-run]"
	case "${3:-}" in "") ;; --dry-run) dry_run=1 ;; *) die "unknown argument ${3}" ;; esac
	[ $# -le 3 ] || die "too many arguments"
	[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like 0.1.1"
	[ -s "$notes" ] || die "notes file $notes is missing or empty"
	notes=$(absolute "$notes")
	cd "$(git rev-parse --show-toplevel)"
	! git rev-parse -q --verify "refs/tags/v$version" >/dev/null || die "tag v$version exists"
	check_clean_main
	check_ci_green
	scripts/scan-secrets.sh --notes "$notes" || die "the notes file did not pass the scan"
	if [ "$dry_run" = 1 ]; then
		echo "dry run: would bump $spec to $version, commit 'chore: release $version', scan, tag v$version"
		return
	fi
	trap 'print_undo "$version"' ERR
	bump_spec "$version"
	commit_release "$version"
	tag_release "$version" "$notes"
	echo "tagged v$version. To publish:"
	echo "  git push origin main"
	echo "  git push origin v$version"
}

main "$@"
