#!/usr/bin/env pwsh
# publish.ps1 — sync wang-ning-wiki changes to Quartz and push to GitHub Pages
# Usage: .\publish.ps1 [-Message "custom commit message"] [-NoTag]

param(
    [string]$Message = "",
    [switch]$NoTag
)

$ErrorActionPreference = "Stop"
$WikiDir   = "E:\wiki\wang-ning-wiki\wiki"
$ContentDir = "$PSScriptRoot\content"

# 1. Sync wiki pages
Write-Host "Syncing wiki pages..." -ForegroundColor Cyan
$wikiItems = @("entities", "concepts", "topics", "summaries", "index.md", "log.md")
foreach ($item in $wikiItems) {
    $src = "$WikiDir\$item"
    $dst = "$ContentDir\$item"
    if (Test-Path $src -PathType Container) {
        if (!(Test-Path $dst)) { New-Item -ItemType Directory -Path $dst | Out-Null }
        Copy-Item -Path "$src\*" -Destination $dst -Recurse -Force
        Write-Host "  + synced $item\" -ForegroundColor Green
    } elseif (Test-Path $src -PathType Leaf) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Host "  + synced $item" -ForegroundColor Green
    } else {
        Write-Host "  ! not found: $item" -ForegroundColor Yellow
    }
}

# 2. Determine version tag
$today = Get-Date -Format "yyyy.MM.dd"
$existing = git tag --list "v$today*" 2>$null
if ($existing) {
    $nums = $existing | ForEach-Object { if ($_ -match "v\d+\.\d+\.\d+\.(\d+)") { [int]$Matches[1] } else { 0 } }
    $next = ($nums | Measure-Object -Maximum).Maximum + 1
    $version = "v$today.$next"
} else {
    $version = "v$today"
}

# 3. Commit message
if (-not $Message) { $Message = "publish $version" }

# 4. Git add + commit
Write-Host "Committing ($version)..." -ForegroundColor Cyan
git add content/
$status = git status --short content/
if (-not $status) {
    Write-Host "Nothing to commit." -ForegroundColor Yellow
    exit 0
}
git commit -m $Message
Write-Host "  + committed" -ForegroundColor Green

# 5. Tag
if (-not $NoTag) {
    git tag $version
    Write-Host "  + tagged $version" -ForegroundColor Green
}

# 6. Push
Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push origin HEAD:main
if (-not $NoTag) { git push origin $version }
Write-Host "Done. Site will update in ~2 minutes." -ForegroundColor Green
Write-Host "  https://wangning.dadao.fan/" -ForegroundColor Blue

# 7. Append to CHANGELOG
$changelogPath = "$PSScriptRoot\CHANGELOG.md"
$entry = "## $version — $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n$Message`n"
$entry | Out-File -FilePath $changelogPath -Append -Encoding utf8
