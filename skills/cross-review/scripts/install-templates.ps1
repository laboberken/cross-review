# Install the herdr-core reviewer templates.
#
# The templates carry the read-only contract that every reviewer agent runs
# under. Each agent needs its own template because the template also carries
# that agent's launch line.
#
#   pwsh -File scripts/install-templates.ps1

$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $here '..\templates'
$target = if ($env:APPDATA) { Join-Path $env:APPDATA 'herdr-core\templates' } else { Join-Path $HOME '.config/herdr-core/templates' }

if (-not (Test-Path $source)) { Write-Error "templates not found: $source"; exit 1 }
New-Item -ItemType Directory -Force -Path $target | Out-Null

$installed = 0
foreach ($tpl in Get-ChildItem $source -Filter '*.md') {
    Copy-Item $tpl.FullName (Join-Path $target $tpl.Name) -Force
    Write-Output "  installed $($tpl.Name)"
    $installed++
}

Write-Output ""
Write-Output "installed $installed template(s) into $target"
Write-Output "verify with:  hc templates"
