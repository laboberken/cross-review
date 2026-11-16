#!/usr/bin/env sh
# Mirror the shared skills into Codex's skill root.
#
# Claude Code reads ~/.claude/skills natively. opencode reads it as a
# compatibility source. Codex does NOT: it only reads ~/.codex/skills (or
# $CODEX_HOME/skills). `npx skills add` fills that directory itself when codex
# is one of the selected agents, so this script is only needed for a
# by-hand install, or to repair the mirror after a selective agent choice.
#
# The shared skill set is the UNION of ~/.agents/skills (where `npx skills add`
# puts the files it manages) and ~/.claude/skills (where manually installed
# skills live, and where the CLI links the ones from ~/.agents/skills). Reading
# only one of the two would delete the other's skills from Codex.
#
# Codex's own ~/.codex/skills/.system is left alone.
#
#   sh scripts/sync-codex-skills.sh
#
# POSIX sh only: this runs under dash on CI images, which has no arrays.

set -eu

src_agents="$HOME/.agents/skills"
src_claude="$HOME/.claude/skills"

if [ ! -d "$src_agents" ] && [ ! -d "$src_claude" ]; then
  echo "no skill source found (looked in $src_agents and $src_claude)" >&2
  exit 1
fi

target_dir="${CODEX_HOME:-$HOME/.codex}/skills"
mkdir -p "$target_dir"

# Enumerate wanted skills as "name<TAB>realpath" pairs, earlier roots winning.
# A temp file stands in for an associative array, which dash does not have.
list=$(mktemp)
trap 'rm -f "$list"' EXIT

for root in "$src_agents" "$src_claude"; do
  [ -d "$root" ] || continue
  for skill in "$root"/*; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    # Earlier roots win: skip a name already recorded.
    if cut -f1 "$list" | grep -qx "$name"; then
      continue
    fi
    if [ -L "$skill" ]; then
      real=$(readlink -f "$skill" 2>/dev/null || readlink "$skill")
    else
      real="$skill"
    fi
    printf '%s\t%s\n' "$name" "$real" >> "$list"
  done
done

created=0
removed=0
kept=0

# Drop links whose skill is in neither source root.
for link in "$target_dir"/*; do
  [ -e "$link" ] || continue
  [ -L "$link" ] || continue
  name=$(basename "$link")
  [ "$name" = ".system" ] && continue
  if ! cut -f1 "$list" | grep -qx "$name"; then
    rm "$link"
    removed=$((removed + 1))
  fi
done

# Create or refresh one link per shared skill.
while IFS="$(printf '\t')" read -r name real; do
  [ -n "$name" ] || continue
  link="$target_dir/$name"
  if [ -L "$link" ]; then
    current=$(readlink -f "$link" 2>/dev/null || readlink "$link")
    if [ "$current" = "$real" ]; then
      kept=$((kept + 1))
      continue
    fi
    rm "$link"
    ln -s "$real" "$link"
    created=$((created + 1))
  elif [ -e "$link" ]; then
    echo "warning: $link is a real directory, leaving it alone" >&2
    kept=$((kept + 1))
  else
    ln -s "$real" "$link"
    created=$((created + 1))
  fi
done < "$list"

echo "codex skills mirrored: $created created, $removed removed, $kept unchanged"
echo "  target: $target_dir"
