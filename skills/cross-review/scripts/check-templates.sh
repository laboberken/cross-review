#!/usr/bin/env sh
# Verify the installed reviewer templates match the ones this skill ships,
# byte for byte — frontmatter and body.
#
# Why this exists: a v1 template satisfies "hc templates lists reviewer", so
# L3 preflight passed while reviewers wrote findings under .review/ instead
# of <git-dir>/cross-review/. And hc's own listing cannot see the body:
# measured, `hc templates --json` exposes only name, command and
# description, so a frontmatter-only check missed every body drift — a
# template carrying an old finding format or an old delivery command passed.
# This script compares the installed files against the shipped ones
# directly, so every byte is guarded.
#
#   sh scripts/check-templates.sh                 # locate the install and check it
#   sh scripts/check-templates.sh <DIR>           # check DIR as if it were the install
#
# The default mode asks locate-templates.sh where hc reads, then proves hc
# actually lists every shipped template — a copy hc cannot see is the defect
# that started this script, wearing a new coat. With a DIR argument the
# check is purely on-disk, so CI can exercise it without hc.
#
# Exit 0 = every shipped template is installed and byte-identical.
# Exit 1 = a template is missing or its contents drifted.
# Exit 2 = cannot run (no install location, no hc, or unusable DIR).
#
# POSIX sh only: this runs under dash on CI images, which has no arrays.

set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
source_dir="$here/../templates"

if [ $# -gt 1 ]; then
  echo "usage: check-templates.sh [DIR]" >&2
  exit 2
fi

if [ $# -eq 1 ]; then
  target=$1
  if [ ! -d "$target" ]; then
    echo "not a directory: $target" >&2
    exit 2
  fi
else
  target=$(sh "$here/locate-templates.sh") || {
    echo "cannot locate the installed templates" >&2
    echo "  reinstall: sh $here/install-templates.sh" >&2
    exit 2
  }

  # hc must list every shipped template. Files matching on disk in a
  # directory hc does not read are the v1 defect in a new coat.
  if ! command -v hc >/dev/null 2>&1; then
    echo "no hc on PATH, so hc's own view cannot be checked" >&2
    exit 2
  fi
  if ! json=$(hc templates --json 2>/dev/null); then
    echo "hc templates --json failed" >&2
    exit 2
  fi
  unseen=""
  for tpl in "$source_dir"/*.md; do
    [ -e "$tpl" ] || continue
    name=$(basename "$tpl" .md)
    if printf '%s' "$json" | grep -q "\"name\"[[:space:]]*:[[:space:]]*\"$name\""; then
      :
    else
      unseen="$unseen $name"
    fi
  done
  if [ -n "$unseen" ]; then
    echo "TEMPLATE CHECK FAILED - hc cannot see:$unseen" >&2
    echo "  hc reads: $target" >&2
    echo "  reinstall: sh $here/install-templates.sh" >&2
    exit 1
  fi
fi

missing=""
drifted=""
detail=""
checked=0

for tpl in "$source_dir"/*.md; do
  [ -e "$tpl" ] || continue
  name=$(basename "$tpl" .md)
  installed="$target/$(basename "$tpl")"
  checked=$((checked + 1))
  if [ ! -e "$installed" ]; then
    missing="$missing $name"
    continue
  fi
  if ! cmp -s "$tpl" "$installed"; then
    drifted="$drifted $name"
    diff_line=$(cmp "$tpl" "$installed" 2>&1 || true)
    detail="$detail
  $name
    $diff_line"
  fi
done

if [ -n "$missing" ]; then
  echo "TEMPLATE CHECK FAILED - not installed:$missing" >&2
  echo "  reading: $target" >&2
  echo "  reinstall: sh $here/install-templates.sh" >&2
  exit 1
fi

if [ -n "$drifted" ]; then
  echo "TEMPLATE CHECK FAILED - stale:$drifted" >&2
  printf '%s\n' "$detail" >&2
  echo "" >&2
  echo "  reinstall: sh $here/install-templates.sh" >&2
  exit 1
fi

echo "template check passed ($checked template(s) byte-identical)"
