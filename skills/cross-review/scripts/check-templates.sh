#!/usr/bin/env sh
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
#
# POSIX sh only: this runs under dash on CI images, which has no arrays.

set -eu

here=$(cd "$(dirname "$0")" && pwd -P)
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

# Pull one field for one template out of the listing. A narrow parse: the
# listing is a flat array of objects with string fields, and jq is not a
# dependency this script wants to take on.
field_of() {
  printf '%s' "$json" | python -c '
import json, sys
want_name, want_key = sys.argv[1], sys.argv[2]
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
for entry in data.get("templates", []):
    if entry.get("name") == want_name:
        print(entry.get(want_key, ""))
        break
' "$1" "$2" 2>/dev/null || true
}

# The same field, read from a shipped template's frontmatter.
shipped_field_of() {
  python - "$1" "$2" <<'PY' 2>/dev/null || true
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

missing=""
drifted=""
detail=""
checked=0

for tpl in "$source_dir"/*.md; do
  [ -e "$tpl" ] || continue
  name=$(basename "$tpl" .md)
  checked=$((checked + 1))

  installed_command=$(field_of "$name" command)
  if [ -z "$installed_command" ]; then
    missing="$missing $name"
    continue
  fi

  for key in command description; do
    want=$(shipped_field_of "$tpl" "$key")
    [ -z "$want" ] && continue
    got=$(field_of "$name" "$key")
    if [ "$want" != "$got" ]; then
      drifted="$drifted $name($key)"
      detail="$detail
  $name $key
    installed: $got
    shipped:   $want"
    fi
  done
done

if [ -n "$missing" ]; then
  echo "TEMPLATE CHECK FAILED — not installed:$missing" >&2
  echo "  reinstall: sh $here/install-templates.sh" >&2
  exit 1
fi

if [ -n "$drifted" ]; then
  echo "TEMPLATE CHECK FAILED — stale:$drifted" >&2
  printf '%s\n' "$detail" >&2
  echo "" >&2
  echo "  reinstall: sh $here/install-templates.sh" >&2
  exit 1
fi

echo "template check passed ($checked template(s))"
