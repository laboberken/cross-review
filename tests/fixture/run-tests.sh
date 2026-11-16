#!/usr/bin/env sh
# Run the cross-review v2 fixture.
#
# Standard library only: this machine has Python 3.15.1 and no pytest, which is
# the premise the skill's test-command preflight exists for.
#
#   sh run-tests.sh          # expect RED on A and B: the defects are planted
#   sh run-tests.sh fixed    # expect GREEN: same tests, corrected module
#   sh run-tests.sh ac       # A and C only, in isolation
#   sh run-tests.sh b        # B only
#
# Same modes as run-tests.ps1; CI runs both runners so they cannot drift.
#
# POSIX sh only: this runs under dash on CI images, which has no arrays.

set -eu

here=$(cd "$(dirname "$0")" && pwd)
# CI images ship python3; Windows machines often only python. Probe once.
py=$(command -v python || command -v python3) || {
  echo "no python or python3 on PATH" >&2
  exit 2
}
# unittest -k takes a substring glob, not a regex, so the cases are selected
# by name rather than by an alternation.
case "${1:-all}" in
  ac) exec "$py" -m unittest discover -s "$here" -p 'tests.py' -k 'CaseA' -k 'CaseC' -v ;;
  b)  exec "$py" -m unittest discover -s "$here" -p 'tests.py' -k 'CaseB' -v ;;
  fixed) export CR_FIXTURE_MODULE=fixed; exec "$py" -m unittest discover -s "$here" -p 'tests.py' -v ;;
  *)  exec "$py" -m unittest discover -s "$here" -p 'tests.py' -v ;;
esac
