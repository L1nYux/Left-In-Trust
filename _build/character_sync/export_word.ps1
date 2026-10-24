param([string]$Root = 'D:\MyPros\AI游戏', [string]$Only = '')
$ErrorActionPreference = 'Stop'
$exportDir = Join-Path $Root '_build\character_sync\pdf'
New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
$wordExporter = $null
try {
    $wordExporter = New-Object -ComObject Word.Application
    $wordExporter.Visible = $false
    $wordExporter.DisplayAlerts = 0
    $wordExporter.AutomationSecurity = 3
    $docs = Get-ChildItem -LiteralPath (Join-Path $Root '角色设定\性格') -Filter '*.docx' -File | Sort-Object Name
    foreach ($file in $docs) {
        if ($Only -and $file.BaseName -ne $Only) { continue }
        $openedDoc = $null
        try {
            $openedDoc = $wordExporter.Documents.Open($file.FullName, $false, $true, $false)
            $openedDoc.Repaginate()
            $pdfFile = Join-Path $exportDir ($file.BaseName + '.pdf')
            $openedDoc.ExportAsFixedFormat($pdfFile, 17)
            Write-Output ('Exported ' + $file.Name + ' pages=' + $openedDoc.ComputeStatistics(2))
        } finally {
            if ($null -ne $openedDoc) { $openedDoc.Close(0) }
        }
    }
} finally {
    if ($null -ne $wordExporter) { $wordExporter.Quit(0) }
}
