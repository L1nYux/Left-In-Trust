param(
    [string]$GodotPath = "",
    [string]$NodePath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$gameRoot = Join-Path $repoRoot "game"
$evidenceRoot = Join-Path $PSScriptRoot "evidence\test-logs"
$godotLogRoot = Join-Path $gameRoot ".godot"

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $bundledGodot = Join-Path $repoRoot ".tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
    if (Test-Path -LiteralPath $bundledGodot) {
        $GodotPath = $bundledGodot
    } else {
        $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
        if ($null -ne $godotCommand) {
            $GodotPath = $godotCommand.Source
        }
    }
}
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found: $GodotPath"
}

if ([string]::IsNullOrWhiteSpace($NodePath)) {
    $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
    if ($null -ne $nodeCommand) {
        $NodePath = $nodeCommand.Source
    } else {
        $NodePath = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"
    }
}
if (-not (Test-Path -LiteralPath $NodePath)) {
    throw "Node executable not found: $NodePath"
}

New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
New-Item -ItemType Directory -Force -Path $godotLogRoot | Out-Null
$utf8 = [System.Text.UTF8Encoding]::new($false)
$summaries = [System.Collections.Generic.List[string]]::new()

function Invoke-LoggedCommand {
    param(
        [string]$Name,
        [string]$Executable,
        [string[]]$Arguments,
        [switch]$MirrorToGodot
    )

    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Executable @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorPreference
    }
    $rawText = ($output | Out-String)
    $normalizedLines = ($rawText -split "`r?`n") | ForEach-Object { $_.TrimEnd() }
    $text = ($normalizedLines -join [Environment]::NewLine).TrimEnd() + [Environment]::NewLine
    $evidencePath = Join-Path $evidenceRoot "$Name.log"
    [System.IO.File]::WriteAllText($evidencePath, $text, $utf8)
    if ($MirrorToGodot) {
        $mirrorLogPath = Join-Path $godotLogRoot "$Name.log"
        [System.IO.File]::WriteAllText($mirrorLogPath, $text, $utf8)
    }
    Write-Host $text.TrimEnd()
    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode"
    }
    $summaries.Add("$Name PASS")
}

Push-Location $repoRoot
try {
    Invoke-LoggedCommand "data-sync" "powershell.exe" @("-ExecutionPolicy", "Bypass", "-File", ".\_build\sync_game_data.ps1", "-Check")
    Invoke-LoggedCommand "node-validation" $NodePath @(".\_build\validate_gameplay_v05.cjs")

    $godotTests = [ordered]@{
        "rule-tests" = "res://tests/test_rules.gd"
        "audit-probe" = "res://tests/audit_probe.gd"
        "smoke-runs" = "res://tests/smoke_runs.gd"
        "ui-flows" = "res://tests/test_ui_flows.gd"
        "ui-click-tests" = "res://tests/test_ui_clicks.gd"
        "multiplayer-tests" = "res://tests/test_multiplayer.gd"
        "save-tests" = "res://tests/test_save_manager.gd"
    }
    foreach ($entry in $godotTests.GetEnumerator()) {
        Invoke-LoggedCommand $entry.Key $GodotPath @("--headless", "--path", ".\game", "--script", $entry.Value) -MirrorToGodot
    }
} finally {
    Pop-Location
}

$summaryText = ($summaries -join [Environment]::NewLine) + [Environment]::NewLine
[System.IO.File]::WriteAllText((Join-Path $evidenceRoot "stage2-tests-summary.log"), $summaryText, $utf8)
Write-Host $summaryText.TrimEnd()
