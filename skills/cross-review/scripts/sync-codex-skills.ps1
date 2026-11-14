# Mirror the shared skills into Codex's skill root.
#
# Claude Code reads ~/.claude/skills natively. opencode reads it as a
# compatibility source. Codex does NOT: it only reads ~/.codex/skills (or
# $CODEX_HOME/skills). This script keeps ~/.codex/skills in step by creating
# one directory junction per skill.
#
# Run it after adding, renaming, or removing a skill in ~/.claude/skills.
# Codex's own ~/.codex/skills/.system is left alone.
#
#   pwsh -File ~/.claude/sync-codex-skills.ps1

$ErrorActionPreference = 'Stop'

$source = Join-Path $HOME '.claude\skills'
$target = Join-Path $HOME '.codex\skills'

if (-not (Test-Path $source)) { Write-Error "source not found: $source"; exit 1 }
New-Item -ItemType Directory -Force -Path $target | Out-Null

$created = 0
$removed = 0
$kept = 0

# Drop junctions whose source skill is gone.
foreach ($link in Get-ChildItem $target -Directory -Force) {
    if ($link.Name -eq '.system') { $kept++; continue }
    if ($link.LinkType -eq 'Junction') {
        $origin = Join-Path $source $link.Name
        if (-not (Test-Path $origin)) {
            Remove-Item $link.FullName -Force
            $removed++
        }
    }
}

# Create or refresh one junction per shared skill.
foreach ($skill in Get-ChildItem $source -Directory -Force) {
    $link = Join-Path $target $skill.Name
    if (Test-Path $link) {
        $item = Get-Item $link -Force
        if ($item.LinkType -eq 'Junction') {
            if ($item.Target -ne $skill.FullName) {
                Remove-Item $link -Force
                New-Item -ItemType Junction -Path $link -Target $skill.FullName | Out-Null
                $created++
            } else {
                $kept++
            }
        } else {
            # A real directory is sitting where a junction belongs: move it
            # aside rather than destroy it.
            $backup = "$link.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Move-Item $link $backup
            New-Item -ItemType Junction -Path $link -Target $skill.FullName | Out-Null
            Write-Warning "real directory moved aside: $backup"
            $created++
        }
    } else {
        New-Item -ItemType Junction -Path $link -Target $skill.FullName | Out-Null
        $created++
    }
}

Write-Output "codex skills mirrored: $created created, $removed removed, $kept unchanged"
Write-Output "  source: $source"
Write-Output "  target: $target"
