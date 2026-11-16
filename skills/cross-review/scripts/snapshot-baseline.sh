#!/usr/bin/env sh
# Snapshot the working tree of the repository in the current directory as a
# git tree object, without touching the real index, the working tree, or the
# branch history.
#
# Why this exists: a review must pin its baseline without a clean working
# tree and without leaving a commit behind (design.md D8, D10). The tree is
# captured through a throwaway index, so untracked files are included and no
# ref is written. `git stash create -u` cannot do this: measured, it
# snapshots the tree as it already is, so `git diff $sha` comes back empty,
# and `git diff <commit>` drops untracked files anyway.
#
#   sh scripts/snapshot-baseline.sh
#
# Output (stdout), two shell-sourceable lines:
#   BASE=<head sha>     the commit a round-1 diff is measured from
#   SNAP=<tree sha>     the working tree, immutable
#
# Fails with a non-zero exit if HEAD cannot resolve or the snapshot fails.
#
# POSIX sh only: this runs under dash on CI images, which has no arrays.

set -eu

BASE=$(git rev-parse HEAD)
idx=$(mktemp)
trap 'rm -f "$idx"' EXIT

GIT_INDEX_FILE=$idx git read-tree HEAD
GIT_INDEX_FILE=$idx git add -A
SNAP=$(GIT_INDEX_FILE=$idx git write-tree)

printf 'BASE=%s\nSNAP=%s\n' "$BASE" "$SNAP"
