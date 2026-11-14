#!/usr/bin/env bash
# Install the herdr-core reviewer templates.
#
# The templates carry the read-only contract that every reviewer agent runs
# under. Each agent needs its own template because the template also carries
# that agent's launch line.
#
#   sh scripts/install-templates.sh

set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source_dir="$here/../templates"

if [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/herdr-core" ]; then
  target="${XDG_CONFIG_HOME:-$HOME/.config}/herdr-core/templates"
else
  target="$HOME/.config/herdr-core/templates"
fi

mkdir -p "$target"

installed=0
for tpl in "$source_dir"/*.md; do
  [ -e "$tpl" ] || continue
  cp "$tpl" "$target/"
  echo "  installed $(basename "$tpl")"
  installed=$((installed + 1))
done

echo ""
echo "installed $installed template(s) into $target"
echo "verify with:  hc templates"
