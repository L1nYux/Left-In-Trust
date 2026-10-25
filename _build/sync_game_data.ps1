param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
# Windows PowerShell 5.1 reads BOM-less scripts with the active ANSI code page.
# Build the non-ASCII source name from code points so the documented command
# works consistently without duplicating or renaming the canonical data file.
$contentFileName = "$([char]0x9996)$([char]0x6279)$([char]0x5185)$([char]0x5BB9).json"
$source = Join-Path (Join-Path $repoRoot "docs") $contentFileName
$targetDir = Join-Path $repoRoot "game\data"
$target = Join-Path $targetDir "content.json"
$hashFile = Join-Path $targetDir "content.sha256"

if (-not (Test-Path -LiteralPath $source)) {
    throw "Missing source data: $source"
}

$raw = [System.IO.File]::ReadAllText($source, [System.Text.Encoding]::UTF8)
$data = $raw | ConvertFrom-Json

if ($data.version -ne "0.5") { throw "Expected content version 0.5" }
if ($data.cards.Count -ne 12) { throw "Expected exactly 12 card definitions" }
if ($data.roles.Count -lt 3) { throw "Expected at least three playable roles" }

$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()

if ($Check) {
    if (-not (Test-Path -LiteralPath $target) -or -not (Test-Path -LiteralPath $hashFile)) {
        throw "Generated game data is missing. Run _build\sync_game_data.ps1"
    }
    $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $recordedHash = ([System.IO.File]::ReadAllText($hashFile)).Trim()
    if ($sourceHash -ne $targetHash -or $sourceHash -ne $recordedHash) {
        throw "Generated game data is stale. Run _build\sync_game_data.ps1"
    }
    Write-Host "Game data is current ($sourceHash)"
    exit 0
}

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
[System.IO.File]::WriteAllText($target, $raw, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($hashFile, "$sourceHash`n", [System.Text.UTF8Encoding]::new($false))
Write-Host "Generated game/data/content.json from docs/首批内容.json"
Write-Host "SHA256 $sourceHash"
