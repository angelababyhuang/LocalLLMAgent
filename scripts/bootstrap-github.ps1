# scripts/bootstrap-github.ps1
#
# One-shot: push this repo to GitHub and turn the local Wayfinder map into
# GitHub issues (map + child tickets + native sub-issue and blocked_by links).
#
# Prerequisites (run once): git, gh CLI, and `gh auth login`.
# Run once from the repo root (or any dir: -Root is derived from the script path):
#   pwsh -File scripts\bootstrap-github.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\bootstrap-github.ps1
#
# Safe to inspect before running; it aborts if a wayfinder:map issue already exists.

param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$Repo = 'angelababyhuang/LocalLLMAgent'
)

$ErrorActionPreference = 'Stop'
Set-Location $Root

$mapDir  = Join-Path $Root '.scratch/local-multimodal-platform'
$issueDir = Join-Path $mapDir 'issues'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git not found on PATH.' }
if (-not (Get-Command gh  -ErrorAction SilentlyContinue)) { throw 'gh CLI not found on PATH. Install: winget install GitHub.cli' }

gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw 'gh is not authenticated. Run: gh auth login' }
gh auth setup-git *> $null   # let git use gh credentials for the push below

# ---------------------------------------------------------------- 1. git push
if (-not (Test-Path (Join-Path $Root '.git'))) { git init | Out-Null }
$null = git remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0) { git remote add origin "https://github.com/$Repo.git" }

git add -A
$null = git commit -m 'chore: bootstrap repo, wayfinder map and research' 2>$null
git branch -M main
git push -u origin main
if ($LASTEXITCODE -ne 0) { throw 'git push failed (check credentials / that the remote repo is empty).' }

# ---------------------------------------------------------------- 2. labels
$labels = @(
    @{ name = 'wayfinder:map';       color = '0e8a16'; desc = 'Wayfinder map issue' },
    @{ name = 'wayfinder:research';  color = '1d76db'; desc = 'Wayfinder research ticket (AFK)' },
    @{ name = 'wayfinder:prototype'; color = 'd93f0b'; desc = 'Wayfinder prototype ticket (HITL)' },
    @{ name = 'wayfinder:grilling';  color = '5319e7'; desc = 'Wayfinder grilling ticket (HITL)' },
    @{ name = 'wayfinder:task';      color = 'fbca04'; desc = 'Wayfinder task ticket' }
)
foreach ($l in $labels) {
    gh label create $l.name --color $l.color --description $l.desc --force *> $null
}

# ---------------------------------------------------------------- 3. guard
$existing = gh issue list --label 'wayfinder:map' --state all --json number --jq '.[0].number' 2>$null
if ($existing -and $existing.Trim() -ne 'null') {
    throw "A wayfinder:map issue already exists (#$($existing.Trim())). Aborting to avoid duplicates."
}

# ---------------------------------------------------------------- 4. map issue
$mapTitle = '本地多模态智能体平台 · Wayfinder 地图'
$mapUrl = (gh issue create --title $mapTitle --label 'wayfinder:map' --body-file (Join-Path $mapDir 'map.md')).Trim()
$mapNum = [int]($mapUrl -replace '^.*/', '')
Write-Host "Map issue: #$mapNum  $mapUrl"

# ---------------------------------------------------------------- 5. tickets
# Order matters: blockers are created before the tickets that depend on them.
$tickets = @(
    @{ file = '01-taxonomy.md';             type = 'grilling';  blockedBy = @() },
    @{ file = '02-process-memory.md';       type = 'grilling';  blockedBy = @() },
    @{ file = '03-sensitive-governance.md'; type = 'grilling';  blockedBy = @() },
    @{ file = '04-gate-spike.md';           type = 'prototype'; blockedBy = @('01-taxonomy.md') },
    @{ file = '05-video-model.md';          type = 'grilling';  blockedBy = @('01-taxonomy.md') },
    @{ file = '06-data-model.md';           type = 'grilling';  blockedBy = @('01-taxonomy.md') },
    @{ file = '07-workbench-graph.md';      type = 'grilling';  blockedBy = @('06-data-model.md') }
)

$created = @{}
$subIssueFailures = 0
$depFailures = 0

foreach ($t in $tickets) {
    $path = Join-Path $issueDir $t.file
    $raw  = Get-Content $path -Raw

    $title = ([regex]::Match($raw, '(?m)^#\s+(.+)$')).Groups[1].Value.Trim()
    if (-not $title) { throw "No title found in $($t.file)" }

    $body = $raw -replace '(?m)^#\s+.+$', '' -replace '(?m)^Type:.*$', '' -replace '(?m)^Blocked by:.*$', ''
    $body = $body.Trim()

    $prefix = "Part of #$mapNum"
    $blockedNums = @()
    foreach ($bf in $t.blockedBy) {
        if (-not $created.ContainsKey($bf)) { throw "Blocker $bf not created yet for $($t.file)" }
        $blockedNums += $created[$bf]
    }
    if ($blockedNums.Count -gt 0) {
        $prefix += "`nBlocked by: " + (($blockedNums | ForEach-Object { "#$_" }) -join ', ')
    }

    $url = (gh issue create --title $title --label "wayfinder:$($t.type)" --body "$prefix`n`n$body").Trim()
    $num = [int]($url -replace '^.*/', '')
    $created[$t.file] = $num
    Write-Host ("  {0,-32} -> #{1}  {2}" -f $t.file, $num, $url)

    # Best-effort native sub-issue link (falls back to the "Part of #" line).
    try {
        $childId = (gh api "repos/$Repo/issues/$num" --jq '.id').Trim()
        gh api --method POST "repos/$Repo/issues/$mapNum/sub_issues" -F sub_issue_id=$childId *> $null
        if ($LASTEXITCODE -ne 0) { $subIssueFailures++ }
    } catch { $subIssueFailures++ }

    # Best-effort native blocked_by dependencies (falls back to the "Blocked by:" line).
    foreach ($bn in $blockedNums) {
        try {
            $blockerId = (gh api "repos/$Repo/issues/$bn" --jq '.id').Trim()
            gh api --method POST "repos/$Repo/issues/$num/dependencies/blocked_by" -F issue_id=$blockerId *> $null
            if ($LASTEXITCODE -ne 0) { $depFailures++ }
        } catch { $depFailures++ }
    }
}

Write-Host ''
Write-Host "Done. Map: #$mapNum  Tickets: $($created.Values.Count)"
if ($subIssueFailures -gt 0) { Write-Warning "$subIssueFailures sub-issue link(s) failed; the 'Part of #' line still records parentage." }
if ($depFailures    -gt 0) { Write-Warning "$depFailures dependency edge(s) failed; the 'Blocked by:' line still gates the frontier." }
Write-Host 'The .scratch/local-multimodal-platform/ directory was left in place; delete it once you have verified the issues.'
