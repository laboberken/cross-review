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
# Where they go is not guessable: `hc` reads %APPDATA%\herdr-core\templates on
# Windows and honours nothing else there (measured: XDG_CONFIG_HOME is ignored),
# while on Unix it reads $XDG_CONFIG_HOME/herdr-core or ~/.config/herdr-core.
# Rather than trust the guess, this script probes, copies, then reads back
# through `hc templates` and fails if the copy is not visible.
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

# `hc` reads %APPDATA% on Windows, and ignores XDG_CONFIG_HOME there.
is_windows=0
[ -n "${APPDATA:-}" ] && is_windows=1

# Candidates, in the order hc is likely to read them on this platform. A
# Windows box keeps a stale ~/.config/herdr-core often enough that putting it
# first would pick the wrong one.
target=""
if [ "$is_windows" -eq 1 ]; then
  set -- "$APPDATA/herdr-core" "$HOME/.config/herdr-core"
else
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    set -- "$XDG_CONFIG_HOME/herdr-core" "$HOME/.config/herdr-core"
  else
    set -- "$HOME/.config/herdr-core"
  fi
fi

for candidate in "$@"; do
  echo "  probed: $candidate"
  if [ -z "$target" ] && [ -d "$candidate" ]; then
    target="$candidate/templates"
  fi
done

if [ -z "$target" ]; then
  if [ "$is_windows" -eq 1 ]; then
    target="$APPDATA/herdr-core/templates"
  elif [ -n "${XDG_CONFIG_HOME:-}" ]; then
    target="$XDG_CONFIG_HOME/herdr-core/templates"
  else
    target="$HOME/.config/herdr-core/templates"
  fi
fi

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
