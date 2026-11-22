#!/usr/bin/env bash
# Prepares a release on main: sets the spec's Version, commits, scans, tags. It never pushes.
# Usage: scripts/release.sh [<base>] <notes-file> [--dry-run]    (needs git and gh)
#        scripts/release.sh --help
# Environment: RELEASE_TRAILER, a line appended to the release commit message (e.g. a Co-Authored-By trailer).
#              RELEASE_STAMP, replaces the UTC date and time of a session release (tests).
#
# Without <base> it makes a session release: the SemVer base of the spec stays, and the version gets the UTC
# date and time and the short hash of main's head behind it: spec 0.1.5^20261122.1830gitabc1234, tag
# v0.1.5+20261122.1830.abc1234. The caret sorts it after the base and before the next one for dnf; the tag cannot
# hold a caret, so it spells the same version as SemVer build metadata. With <base> (x.y.z) it sets a new base, as
# the maintainer asks for a beta, 1.0 or a large step: spec 0.2.0, tag v0.2.0. Versions below 1.0.0 are pre-releases.
#
# The notes file becomes the annotated tag's message (kept verbatim, "#" headings included) and,
# through the workflow, the public GitHub release notes. English, for users: a few bullets per
# area, ticket ids only as "(#<id>)" like in commit subjects, no board internals. The file is scanned
# for secrets and local paths before anything is written. Template:
#
#   rekta-shell 0.1.5+20261122.1830.abc1234
#
#   ## Shell
#   - The Start folds in from the bottom (#<id>)
#
#   ## Packaging
#   - The RPM requires the exact kwin-libs it was built against (#<id>)
set -Eeuo pipefail

spec=packaging/fedora/rekta-shell.spec
required_workflows="privacy nix rpm"
committed=0

die() {
	echo "release: $*" >&2
	exit 1
}

usage() {
	sed -n '2,/^set -Eeuo/p' "$0" | sed -e '/^set -Eeuo/d' -e 's/^# \{0,1\}//'
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

rpm_version_of() {
	local base=$1
	if [ -n "$requested_base" ]; then
		echo "$base"
		return
	fi
	echo "${base}^${RELEASE_STAMP:-$(date -u '+%Y%m%d.%H%M')}git$(git rev-parse --short=7 HEAD)"
}

tag_form() {
	echo "$1" | sed -e 's/\^/+/' -e 's/git/./'
}

bump_spec() {
	local version=$1 entry
	entry="* $(LC_ALL=C date '+%a %b %d %Y') rekta-shell maintainers - $version-1"
	sed -i -e "s/^\(Version:[[:space:]]*\).*/\1$version/" \
		-e "/^%changelog/a $entry\n- Release $(tag_form "$version")" "$spec"
}

commit_release() {
	local version=$1
	git add "$spec"
	git commit --quiet -m "chore: release $(tag_form "$version")" ${RELEASE_TRAILER:+-m "$RELEASE_TRAILER"}
	committed=1
}

tag_release() {
	local tag=v$(tag_form "$1") notes=$2
	scripts/scan-secrets.sh --notes "$notes"
	sh packaging/fedora/ci-check-tag.sh "$tag"
	git tag -a --cleanup=verbatim "$tag" -F "$notes"
}

print_undo() {
	[ "$committed" = 1 ] || return 0
	echo "release failed after the commit. Undo it yourself:" >&2
	echo "  git reset --soft HEAD~1 && git restore --staged $spec && git restore $spec" >&2
	echo "  git tag -d v$(tag_form "$1")   # only if the tag was made" >&2
}

main() {
	local dry_run=0 notes version tag current
	[ "${1:-}" != --help ] || { usage; return; }
	requested_base=
	if [[ ${1:-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		requested_base=$1
		shift
	fi
	notes=${1:-}
	[ -n "$notes" ] || die "usage: release.sh [<base>] <notes-file> [--dry-run]"
	case "${2:-}" in "") ;; --dry-run) dry_run=1 ;; *) die "unknown argument ${2}" ;; esac
	[ $# -le 2 ] || die "too many arguments"
	[ -s "$notes" ] || die "notes file $notes is missing or empty"
	notes=$(absolute "$notes")
	cd "$(git rev-parse --show-toplevel)"
	current=$(sh packaging/version.sh base)
	if [ -n "$requested_base" ] && { [ "$requested_base" = "$current" ] || [ "$(printf '%s\n%s\n' "$current" "$requested_base" | sort -V | tail -n 1)" != "$requested_base" ]; }; then
		die "the new base $requested_base is not above $current"
	fi
	check_clean_main
	version=$(rpm_version_of "${requested_base:-$current}")
	tag=v$(tag_form "$version")
	! git rev-parse -q --verify "refs/tags/$tag" >/dev/null || die "tag $tag exists"
	[ "$version" != "$(sh packaging/version.sh rpm)" ] || die "the spec already has version $version"
	check_ci_green
	scripts/scan-secrets.sh --notes "$notes" || die "the notes file did not pass the scan"
	if [ "$dry_run" = 1 ]; then
		echo "dry run: would set $spec to $version, commit 'chore: release ${tag#v}', scan, tag $tag"
		return
	fi
	trap 'print_undo "$version"' ERR
	bump_spec "$version"
	commit_release "$version"
	tag_release "$version" "$notes"
	echo "tagged $tag. To publish:"
	echo "  git push origin main"
	echo "  git push origin $tag"
}

main "$@"
