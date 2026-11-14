#!/usr/bin/env bash
# Verify the installed reviewer templates match the ones this skill ships.
#
# Why this exists: a v1 template satisfies "hc templates lists reviewer", so
# L3 preflight passed while reviewers wrote findings under .review/ instead of
# <git-dir>/cross-review/. That broke the no-trace guarantee silently. This
# script compares what hc actually has against what the skill carries.
#
#   sh scripts/check-templates.sh                 # ask hc
#   sh scripts/check-templates.sh dump.json       # check a saved listing
#
# Exit 0 = every shipped template is installed and matches.
# Exit 1 = a template is missing, or its command/description has drifted.
# Exit 2 = cannot run (no hc and no JSON argument, or unreadable JSON).

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source_dir="$here/../templates"

json_file="${1:-}"
if [ -n "$json_file" ]; then
  if [ ! -r "$json_file" ]; then
    echo "cannot read: $json_file" >&2
    exit 2
  fi
  json=$(cat "$json_file")
else
  if ! command -v hc >/dev/null 2>&1; then
    echo "no hc on PATH and no JSON argument given" >&2
    exit 2
  fi
  json=$(hc templates --json 2>/dev/null) || {
    echo "hc templates --json failed" >&2
    exit 2
  }
fi

# Extract one field for one template. Deliberately a narrow parse: the JSON is
# a flat array of objects with string fields, and pulling in jq would add a
# dependency this script does not need.
field_of() {
  name="$1" key="$2"
  printf '%s' "$json" | python -c '
import json, sys
want_name, want_key = sys.argv[1], sys.argv[2]
data = json.load(sys.stdin)
for entry in data.get("templates", []):
    if entry.get("name") == want_name:
        print(entry.get(want_key, ""))
        break
' "$name" "$key" 2>/dev/null
}

# The same parse for a shipped template's frontmatter.
shipped_field_of() {
  file="$1" key="$2"
  python - "$file" "$key" <<'PY'
import re, sys
path, key = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
m = re.search(r"^---\s*$(.*?)^---\s*$", text, re.S | re.M)
if not m:
    sys.exit(0)
for line in m.group(1).splitlines():
    if line.startswith(key + ":"):
        print(line.split(":", 1)[1].strip())
        break
PY
}

missing=()
drifted=()
checked=0

for tpl in "$source_dir"/*.md; do
  [ -e "$tpl" ] || continue
  name=$(basename "$tpl" .md)
  checked=$((checked + 1))

  installed_command=$(field_of "$name" command)
  if [ -z "$installed_command" ]; then
    missing+=("$name")
    continue
  fi

  for key in command description; do
    want=$(shipped_field_of "$tpl" "$key")
    [ -z "$want" ] && continue
    got=$(field_of "$name" "$key")
    if [ "$want" != "$got" ]; then
      drifted+=("$name|$key")
    fi
  done
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "TEMPLATE CHECK FAILED — not installed: ${missing[*]}" >&2
  echo "  installed: ${missing[*]}" >&2
  echo "  reinstall: sh $here/install-templates.sh" >&2
  exit 1
fi

if [ ${#drifted[@]} -gt 0 ]; then
  summary=""
  for entry in "${drifted[@]}"; do
    summary="$summary ${entry%%|*}(${entry##*|})"
  done
  echo "TEMPLATE CHECK FAILED — stale:$summary" >&2
  echo "" >&2
  for entry in "${drifted[@]}"; do
    name="${entry%%|*}"
    key="${entry##*|}"
    printf '  %s %s\n    installed: %s\n    shipped:   %s\n' \
      "$name" "$key" "$(field_of "$name" "$key")" "$(shipped_field_of "$source_dir/$name.md" "$key")" >&2
  done
  echo "" >&2
  echo "  reinstall: sh $here/install-templates.sh" >&2
  exit 1
fi

echo "template check passed ($checked template(s))"
