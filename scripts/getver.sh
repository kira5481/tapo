#!/usr/bin/env bash
export LANG=C
export LC_ALL=C
[ -n "$TOPDIR" ] && cd $TOPDIR

try_version() {
	[ -f version ] || return 1
	REV="$(cat version)"
	[ -n "$REV" ]
}

try_svn() {
	[ -d .svn ] || return 1
	REV="$(svn info | awk '/^Last Changed Rev:/ { print $4 }')"
	REV="${REV:+r$REV}"
	[ -n "$REV" ]
}

try_git() {
	[ -d .git ] || [ -d ../.git ] || return 1
	REV="$(git log | git rev-list HEAD --max-count=1 --abbrev-commit --abbrev=8)"
	REV="${REV:+$REV}"
	[ -n "$REV" ]
}

try_hg() {
	[ -d .hg ] || return 1
	REV="$(hg log -r-1 --template '{desc}' | awk '{print $2}' | sed 's/\].*//')"
	REV="${REV:+$REV}"
	[ -n "$REV" ]
}

try_version || try_svn || try_git || try_hg || REV="unknown"
REV=${REV}$(date +_%y%m%d_%H%M%S)
echo "$REV"
