# Run the cross-review v2 fixture.
#
# Standard library only: this machine has Python 3.15.1 and no pytest.
#
#   pwsh -File run-tests.ps1          # expect RED on A and B: the defects are planted
#   pwsh -File run-tests.ps1 fixed    # expect GREEN: same tests, corrected module
#   pwsh -File run-tests.ps1 ac       # A and C only
#   pwsh -File run-tests.ps1 b        # B only
#
# Same modes as run-tests.sh; CI runs both runners so they cannot drift.

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$pattern = if ($args.Count -gt 0) { $args[0] } else { 'all' }

# unittest -k takes a substring glob, not a regex, so the cases are selected
# by name rather than by an alternation. Same selection as run-tests.sh.
$filters = @()
switch ($pattern) {
    'ac'    { $filters = @('CaseA', 'CaseC') }
    'b'     { $filters = @('CaseB') }
    'fixed' { $env:CR_FIXTURE_MODULE = 'fixed' }
    'all'   { }
    default {
        Write-Error "unknown mode: $pattern (all|fixed|ac|b)"
        exit 2
    }
}

$argv = @('-m', 'unittest', 'discover', '-s', $here, '-p', 'tests.py', '-v')
foreach ($f in $filters) { $argv += @('-k', $f) }

& python @argv
exit $LASTEXITCODE
