#!/usr/bin/env sh
# Print the directory hc reads its reviewer templates from — the single
# owner of the candidate order (design.md D21).
#
# Why this exists: where hc reads templates is not guessable. It reads
# %APPDATA%\herdr-core\templates on Windows and honours nothing else there
# (measured: XDG_CONFIG_HOME is ignored), while on Unix it reads
# $XDG_CONFIG_HOME/herdr-core or ~/.config/herdr-core. install-templates
# writes there and check-templates verifies there; the candidate order must
# be identical in both, or the check would verify a directory hc does not
# read while the install wrote a different one.
#
#   sh scripts/locate-templates.sh            # existing herdr-core dir only
#   sh scripts/locate-templates.sh --create   # fall back to the platform default
#
# Output: one line, the templates target path.
# Exit 0 = resolved. Exit 2 = no existing directory (without --create).
#
# POSIX sh only: this runs under dash on CI images, which has no arrays.

set -eu

create=0
for arg in "$@"; do
  case "$arg" in
    --create) create=1 ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

# `hc` reads %APPDATA% on Windows, and ignores XDG_CONFIG_HOME there. A
# Windows box keeps a stale ~/.config/herdr-core often enough that putting
# it first would pick the wrong one. With no existing candidate, the first
# entry is also what --create falls back to.
if [ -n "${APPDATA:-}" ]; then
  set -- "$APPDATA/herdr-core" "$HOME/.config/herdr-core"
else
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    set -- "$XDG_CONFIG_HOME/herdr-core" "$HOME/.config/herdr-core"
  else
    set -- "$HOME/.config/herdr-core"
  fi
fi

for candidate in "$@"; do
  if [ -d "$candidate" ]; then
    echo "$candidate/templates"
    exit 0
  fi
done

if [ "$create" -eq 1 ]; then
  echo "$1/templates"
  exit 0
fi

echo "no herdr-core directory found (tried: $*)" >&2
exit 2
