# Run the cross-review v2 fixture.
#
# Standard library only: this machine has Python 3.15.1 and no pytest.
#
#   pwsh -File run-tests.ps1
#   pwsh -File run-tests.ps1 ac

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$pattern = if ($args.Count -gt 0) { $args[0] } else { 'all' }

# unittest -k takes a substring glob, not a regex, so the cases are selected
# by name rather than by an alternation. Same selection as run-tests.sh.
$filters = switch ($pattern) {
    'ac' { @('CaseA', 'CaseC') }
    'b'  { @('CaseB') }
    default { @() }
}

$argv = @('-m', 'unittest', 'discover', '-s', $here, '-p', 'tests.py', '-v')
foreach ($f in $filters) { $argv += @('-k', $f) }

& python @argv
exit $LASTEXITCODE
