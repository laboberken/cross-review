#!/usr/bin/env bash
# Mirror the shared skills into Codex's skill root.
#
# Claude Code reads ~/.claude/skills natively. opencode reads it as a
# compatibility source. Codex does NOT: it only reads ~/.codex/skills (or
# $CODEX_HOME/skills). `npx skills add` does not fill that directory, so this
# script keeps it in step by creating one link per skill.
#
# The source is ~/.agents/skills when it exists, because that is where
# `npx skills add` puts the real files and links ~/.claude/skills to them.
# Otherwise it falls back to ~/.claude/skills.
#
# Codex's own ~/.codex/skills/.system is left alone.
#
#   sh scripts/sync-codex-skills.sh

set -euo pipefail

source_dir=""
for candidate in "$HOME/.agents/skills" "$HOME/.claude/skills"; do
  if [ -d "$candidate" ]; then source_dir="$candidate"; break; fi
done

if [ -z "$source_dir" ]; then
  echo "no skill source found (looked in ~/.agents/skills and ~/.claude/skills)" >&2
  exit 1
fi

target_dir="${CODEX_HOME:-$HOME/.codex}/skills"
mkdir -p "$target_dir"

created=0
removed=0
kept=0

# Drop links whose source skill is gone.
for link in "$target_dir"/*; do
  [ -e "$link" ] || continue
  [ -L "$link" ] || continue
  name=$(basename "$link")
  [ "$name" = ".system" ] && continue
  if [ ! -d "$source_dir/$name" ]; then
    rm "$link"
    removed=$((removed + 1))
  fi
done

# Create or refresh one link per shared skill.
for skill in "$source_dir"/*; do
  [ -d "$skill" ] || continue
  name=$(basename "$skill")
  link="$target_dir/$name"
  if [ -L "$link" ]; then
    current=$(readlink -f "$link" 2>/dev/null || readlink "$link")
    wanted=$(readlink -f "$skill" 2>/dev/null || echo "$skill")
    if [ "$current" = "$wanted" ]; then
      kept=$((kept + 1))
      continue
    fi
    rm "$link"
    ln -s "$skill" "$link"
    created=$((created + 1))
  elif [ -e "$link" ]; then
    echo "warning: $link is a real directory, leaving it alone" >&2
    kept=$((kept + 1))
  else
    ln -s "$skill" "$link"
    created=$((created + 1))
  fi
done

echo "codex skills mirrored: $created created, $removed removed, $kept unchanged"
echo "  source: $source_dir"
echo "  target: $target_dir"
