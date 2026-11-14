#!/usr/bin/env bash
# Mirror the shared skills into Codex's skill root.
#
# Claude Code reads ~/.claude/skills natively. opencode reads it as a
# compatibility source. Codex does NOT: it only reads ~/.codex/skills (or
# $CODEX_HOME/skills). This script keeps ~/.codex/skills in step by creating
# one directory junction (or symlink) per skill.
#
# Run it after adding, renaming, or removing a skill in ~/.claude/skills.
# Codex's own ~/.codex/skills/.system is left alone.
#
#   sh scripts/sync-codex-skills.sh

set -euo pipefail

source_dir="$HOME/.claude/skills"
target_dir="$HOME/.codex/skills"

if [ ! -d "$source_dir" ]; then
  echo "source not found: $source_dir" >&2
  exit 1
fi
mkdir -p "$target_dir"

created=0
removed=0

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
    current=$(readlink "$link")
    case "$current" in
      "$skill") ;;
      *) rm "$link"; ln -s "$skill" "$link"; created=$((created + 1)) ;;
    esac
  elif [ -e "$link" ]; then
    echo "warning: $link is a real directory, leaving it alone" >&2
  else
    ln -s "$skill" "$link"
    created=$((created + 1))
  fi
done

echo "codex skills mirrored: $created created, $removed removed"
echo "  source: $source_dir"
echo "  target: $target_dir"
