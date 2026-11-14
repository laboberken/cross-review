# Mirror the shared skills into Codex's skill root.
#
# Claude Code reads ~/.claude/skills natively. opencode reads it as a
# compatibility source. Codex does NOT: it only reads ~/.codex/skills (or
# $CODEX_HOME/skills). `npx skills add` does not fill that directory, so this
# script keeps it in step by creating one directory junction per skill.
#
# The source is ~/.agents/skills when it exists, because that is where
# `npx skills add` puts the real files and links ~/.claude/skills to them.
# Otherwise it falls back to ~/.claude/skills.
#
# If a source entry is itself a junction, the link points at its resolved
# target, so junctions never chain.
#
# Codex's own ~/.codex/skills/.system is left alone.
#
#   pwsh -File scripts/sync-codex-skills.ps1

$ErrorActionPreference = 'Stop'

$candidates = @(
    (Join-Path $HOME '.agents\skills'),
    (Join-Path $HOME '.claude\skills')
)
$source = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $source) { Write-Error "no skill source found (looked in $($candidates -join ', '))"; exit 1 }

$target = if ($env:CODEX_HOME) { Join-Path $env:CODEX_HOME 'skills' } else { Join-Path $HOME '.codex\skills' }

New-Item -ItemType Directory -Force -Path $target | Out-Null

$created = 0
$removed = 0
$kept = 0

# Drop junctions whose source skill is gone.
foreach ($link in Get-ChildItem $target -Directory -Force) {
    if ($link.Name -eq '.system') { $kept++; continue }
    if ($link.LinkType -eq 'Junction') {
        if (-not (Test-Path (Join-Path $source $link.Name))) {
            Remove-Item $link.FullName -Force
            $removed++
        }
    }
}

# Create or refresh one junction per shared skill.
foreach ($skill in Get-ChildItem $source -Directory -Force) {
    # Resolve a junction source to its real target so links never chain.
    $real = if ($skill.LinkType -eq 'Junction' -and $skill.Target) { $skill.Target } else { $skill.FullName }

    $link = Join-Path $target $skill.Name
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
Write-Output "  source: $source"
Write-Output "  target: $target"
