# Mirror the shared skills into Codex's skill root.
#
# Claude Code reads ~/.claude/skills natively. opencode reads it as a
# compatibility source. Codex does NOT: it only reads ~/.codex/skills (or
# $CODEX_HOME/skills). `npx skills add` does not fill that directory, so this
# script keeps it in step by creating one directory junction per skill.
#
# The shared skill set is the UNION of ~/.agents/skills (where `npx skills add`
# puts the files it manages) and ~/.claude/skills (where manually installed
# skills live, and where the CLI links the ones from ~/.agents/skills). Reading
# only one of the two would delete the other's skills from Codex.
#
# Junction sources are resolved to their real target, so links never chain.
#
# Codex's own ~/.codex/skills/.system is left alone.
#
#   pwsh -File scripts/sync-codex-skills.ps1

$ErrorActionPreference = 'Stop'

$roots = @(
    (Join-Path $HOME '.agents\skills'),
    (Join-Path $HOME '.claude\skills')
) | Where-Object { Test-Path $_ }

if (-not $roots) {
    Write-Error "no skill source found (looked in ~/.agents/skills and ~/.claude/skills)"
    exit 1
}

# name -> real directory. Earlier roots win, so npx-managed skills resolve to
# their ~/.agents/skills copy rather than through the ~/.claude/skills link.
$wanted = [ordered]@{}
foreach ($root in $roots) {
    foreach ($d in Get-ChildItem $root -Directory -Force) {
        if ($wanted.Contains($d.Name)) { continue }
        $real = if ($d.LinkType -eq 'Junction' -and $d.Target) { $d.Target } else { $d.FullName }
        $wanted[$d.Name] = $real
    }
}

$target = if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME 'skills' } else { Join-Path $HOME '.codex\skills' }
New-Item -ItemType Directory -Force -Path $target | Out-Null

$created = 0
$removed = 0
$kept = 0

# Drop junctions whose skill is in neither source root.
foreach ($link in Get-ChildItem $target -Directory -Force) {
    if ($link.Name -eq '.system') { $kept++; continue }
    if ($link.LinkType -eq 'Junction') {
        if (-not $wanted.Contains($link.Name)) {
            Remove-Item $link.FullName -Force
            $removed++
        }
    }
}

# Create or refresh one junction per shared skill.
foreach ($name in $wanted.Keys) {
    $real = $wanted[$name]
    $link = Join-Path $target $name
    if (Test-Path $link) {
        $item = Get-Item $link -Force
        if ($item.LinkType -eq 'Junction') {
            if ($item.Target -ne $real) {
                Remove-Item $link -Force
                New-Item -ItemType Junction -Path $link -Target $real | Out-Null
                $created++
            } else {
                $kept++
            }
        } else {
            # A real directory is sitting where a junction belongs: move it
            # aside rather than destroy it.
            $backup = "$link.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Move-Item $link $backup
            New-Item -ItemType Junction -Path $link -Target $real | Out-Null
            Write-Warning "real directory moved aside: $backup"
            $created++
        }
    } else {
        New-Item -ItemType Junction -Path $link -Target $real | Out-Null
        $created++
    }
}

Write-Output "codex skills mirrored: $created created, $removed removed, $kept unchanged"
Write-Output "  sources: $($roots -join ', ')"
Write-Output "  target:  $target"
