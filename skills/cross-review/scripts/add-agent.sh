#!/usr/bin/env sh
# Scaffold a reviewer template for a new agent.
#
#   sh scripts/add-agent.sh <name> ["<launch command>"]
#
# With a launch command, the template is ready to install. Without one, it is
# created with a TODO placeholder so the rest can be written first -- and CI
# refuses to let a TODO reach master, so it cannot be forgotten.
#
# The new template is derived from templates/reviewer.md — the thin standing
# rules body — with the launch line replaced. It carries no finding-format
# text: the format has one owner (references/finding-format.md), the packet
# derives its copy at assembly time, and templates defer to the owner.
#
# After running this, add a matching "### <name>" section to
# references/agents.md. CI checks both directions.

set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
templates="$here/../templates"
source="$templates/reviewer.md"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: sh scripts/add-agent.sh <name> [\"<launch command>\"]" >&2
  echo "" >&2
  echo "  e.g. sh scripts/add-agent.sh aider \"aider --no-auto-commits\"" >&2
  echo "       sh scripts/add-agent.sh aider          # TODO placeholder" >&2
  exit 2
fi

name="$1"
command="${2:-TODO}"

case "$name" in
  *[!a-z0-9-]*) echo "name must be lowercase a-z, 0-9 and dashes: $name" >&2; exit 2 ;;
esac

# `reviewer` is the Claude Code template, so a new agent is reviewer-<name>.
if [ "$name" = claude ]; then
  target="$templates/reviewer.md"
else
  target="$templates/reviewer-$name.md"
fi

if [ -e "$target" ]; then
  echo "already exists: $target" >&2
  echo "  edit it directly, or delete it first" >&2
  exit 1
fi

if [ ! -r "$source" ]; then
  echo "missing $source -- cannot derive the template body" >&2
  exit 1
fi

# Replace the launch line in the frontmatter; the body is the shipped body.
# The command reaches awk through the environment, not `-v`: `-v` interprets
# backslash escapes, so a Windows launch line like C:\tools\aider.exe would
# lose its separators (\t became a TAB, measured).
CMD="$command" awk '/^command: / { print "command: " ENVIRON["CMD"]; next } { print }' \
  "$source" > "$target"

echo "wrote $target"
if [ "$command" = "TODO" ]; then
  echo ""
  echo "  command: TODO -- fill in the launch line before merging;"
  echo "  CI refuses a TODO placeholder."
fi
echo ""
echo "Next: add a '### $name' section to references/agents.md."
echo "      CI checks that templates and the registry match both ways."
