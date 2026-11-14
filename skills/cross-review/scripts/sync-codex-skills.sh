#!/usr/bin/env bash
# Mirror the shared skills into Codex's skill root.
#
# Claude Code reads ~/.claude/skills natively. opencode reads it as a
# compatibility source. Codex does NOT: it only reads ~/.codex/skills (or
# $CODEX_HOME/skills). `npx skills add` does not fill that directory, so this
# script keeps it in step by creating one link per skill.
#
# The shared skill set is the UNION of ~/.agents/skills (where `npx skills add`
# puts the files it manages) and ~/.claude/skills (where manually installed
# skills live, and where the CLI links the ones from ~/.agents/skills). Reading
# only one of the two would delete the other's skills from Codex.
#
# Codex's own ~/.codex/skills/.system is left alone.
#
#   sh scripts/sync-codex-skills.sh

set -euo pipefail

roots=()
for candidate in "$HOME/.agents/skills" "$HOME/.claude/skills"; do
  [ -d "$candidate" ] && roots+=("$candidate")
done
if [ ${#roots[@]} -eq 0 ]; then
  echo "no skill source found (looked in ~/.agents/skills and ~/.claude/skills)" >&2
  exit 1
fi

target_dir="${CODEX_HOME:-$HOME/.codex}/skills"
mkdir -p "$target_dir"

# name -> real directory. Earlier roots win.
declare -A wanted
for root in "${roots[@]}"; do
  for skill in "$root"/*; do
    [ -d "$skill" ] || continue
    name=$(basename "$skill")
    [ -n "${wanted[$name]:-}" ] && continue
    if [ -L "$skill" ]; then
      wanted[$name]=$(readlink -f "$skill" 2>/dev/null || readlink "$skill")
    else
      wanted[$name]="$skill"
    fi
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
  if [ -z "${wanted[$name]:-}" ]; then
    rm "$link"
    removed=$((removed + 1))
  fi
done

# Create or refresh one link per shared skill.
for name in "${!wanted[@]}"; do
  real="${wanted[$name]}"
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
done

echo "codex skills mirrored: $created created, $removed removed, $kept unchanged"
echo "  sources: ${roots[*]}"
echo "  target:  $target_dir"
