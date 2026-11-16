#!/usr/bin/env sh
# Install the herdr-core reviewer templates.
#
# The templates carry the read-only contract that every reviewer agent runs
# under. Each agent needs its own template because the template also carries
# that agent's launch line.
#
#   sh scripts/install-templates.sh              # install
#   sh scripts/install-templates.sh --dry-run    # show where it would go
#
# Where they go is not guessable: locate-templates.sh owns the candidate
# order (APPDATA on Windows, XDG or ~/.config on Unix), so the install
# writes where the check will verify. This script resolves the target
# through it, copies, then reads back through `hc templates` and fails if
# the copy is not visible.
#
# POSIX sh only: this runs under dash on CI images, which has no arrays.

set -eu

dry_run=0
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) dry_run=1 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

here=$(cd "$(dirname "$0")" && pwd -P)
source_dir="$here/../templates"

# Where hc reads: locate-templates.sh owns the candidate order, so the
# install writes where the check will verify (design.md D21).
target=$(sh "$here/locate-templates.sh" --create)

echo "target: $target"

if [ "$dry_run" -eq 1 ]; then
  echo ""
  echo "dry run: nothing written"
  exit 0
fi

mkdir -p "$target"

names=""
installed=0
for tpl in "$source_dir"/*.md; do
  [ -e "$tpl" ] || continue
  cp "$tpl" "$target/"
  name=$(basename "$tpl" .md)
  names="$names $name"
  echo "  installed $(basename "$tpl")"
  installed=$((installed + 1))
done

echo ""
echo "installed $installed template(s) into $target"

# Read back through hc. A copy hc cannot see is the whole defect this script
# exists to prevent, so a missing template here is a failure, not a note.
if ! command -v hc >/dev/null 2>&1; then
  echo ""
  echo "note: hc is not on PATH, so the install was NOT verified."
  echo "      run 'hc templates' on a machine with herdr-core to confirm."
  exit 0
fi

json=$(hc templates --json 2>/dev/null || true)
missing=""
for name in $names; do
  if printf '%s' "$json" | grep -q "\"name\"[[:space:]]*:[[:space:]]*\"$name\""; then
    :
  else
    missing="$missing $name"
  fi
done

if [ -n "$missing" ]; then
  echo "" >&2
  echo "FAILED: hc cannot see:$missing" >&2
  echo "  copied into: $target" >&2
  echo "  hc is reading somewhere else. Run 'hc templates' and compare." >&2
  exit 1
fi

echo "verified: hc templates lists$names"
