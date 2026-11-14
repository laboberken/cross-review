#!/usr/bin/env sh
# Scaffold a reviewer template for a new agent.
#
#   sh scripts/add-agent.sh <name> ["<launch command>"]
#
# With a launch command, the template is ready to install. Without one, it is
# created with a TODO placeholder so the rest can be written first -- and CI
# refuses to let a TODO reach master, so it cannot be forgotten.
#
# The new template copies the finding-format block verbatim from
# references/finding-format.md. Do not hand-edit that block: change the source
# and let CI tell you which templates drifted.
#
# After running this, add a matching "### <name>" section to
# references/agents.md. CI checks both directions.

set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
repo="$here/../../.."          # skills/cross-review/scripts -> repo root
templates="$here/../templates"
format="$here/../references/finding-format.md"

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

if [ ! -r "$format" ]; then
  echo "missing $format -- cannot copy the finding contract" >&2
  exit 1
fi

# The shared block: everything from the flagging bar to the end, indented as a
# section of the template body.
python - "$format" "$target" "$command" "$name" <<'PY'
import pathlib, sys

fmt_path, target, command, name = sys.argv[1:5]
text = pathlib.Path(fmt_path).read_text(encoding="utf-8")
marker = "## Flag a finding only when all of these are true"
shared = text[text.index(marker):].rstrip()

body = f"""---
description: Read-only code reviewer. Give it an intent, an axis, a lens, a diff scope and a findings path.
command: {command}
---
You are a read-only code reviewer.

## Rules

- Do NOT modify, create, or delete any file except the findings file whose path
  you are given. That file lives under the rounds directory you are given (`<git-dir>/cross-review/`).
- Do NOT read any other file under the rounds directory. Files there belong to other
  rounds or other reviewers and are NOT part of your input. If your task names
  one previous findings file, that is the only one you may read.
- Do NOT run `git commit`, `git checkout`, `git restore`, `git stash`, `git reset`,
  `git clean`, `git apply`, `git merge`, or `git rebase`.
- Do NOT start another agent, and do NOT delegate the review.
- Read `AGENTS.md` (or `CLAUDE.md`) in the repository first. Treat it as the
  project's standing rules and review against them.

## How to review

1. Inspect the complete diff for the given scope, plus enough surrounding code
   to understand every changed path.
2. Find real problems. Be specific: cite files, lines, and concrete failure
   scenarios.
3. Identify concrete regressions introduced by that change. Continue through the
   whole diff after the first finding.
4. Check the relevant tests and call sites to confirm each finding is real and
   actionable.

## Check the premise you were given

If the scope, base, or intent does not match the repository's actual state,
say so explicitly in the report instead of reviewing the wrong thing.

Also look for contradictions between the project's own rules, and report a
contradiction you find. The reviewers around you will not spot it.

## Stay in your lens, and on your axis

Your task names one lens and one axis. Stay inside both. Report what they cover
and say plainly what they do not. Other reviewers run in parallel on other
pairs; duplicating their work adds noise, not confidence.

## How to report

The reporting contract below is copied verbatim from
`skills/cross-review/references/finding-format.md`. Keep them identical;
CI compares them.

{shared}

## How to finish

Write the findings file FIRST. Only then report back to the parent with this
exact command, replacing the placeholders:

```
hc send <parent-address> "REVIEW DONE: <n> finding(s). <one-line severity summary>. Findings: <findings-path>"
```

The findings file must already be on disk before you send that command: if
your terminal is closed mid-review, the file is the only thing that survives.
Use that exact command so the parent receives your report. Then stop.
"""
pathlib.Path(target).write_text(body, encoding="utf-8", newline="\n")
PY

echo "wrote $target"
if [ "$command" = "TODO" ]; then
  echo ""
  echo "  command: TODO -- fill in the launch line before merging;"
  echo "  CI refuses a TODO placeholder."
fi
echo ""
echo "Next: add a '### $name' section to references/agents.md."
echo "      CI checks that templates and the registry match both ways."
