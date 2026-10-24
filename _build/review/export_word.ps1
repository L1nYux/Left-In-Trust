param([string]$Only='')
$ErrorActionPreference='Stop'
$reviewRoot=Split-Path $PSScriptRoot -Parent
$projectRoot=Split-Path $reviewRoot -Parent
$pdfDir=Join-Path $PSScriptRoot 'pdf'
New-Item -ItemType Directory -Force -Path $pdfDir | Out-Null
$files=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'word_outputs.json') -Raw | ConvertFrom-Json
$wordExporter=$null
try {
  $wordExporter=New-Object -ComObject Word.Application
  $wordExporter.Visible=$false
  $wordExporter.DisplayAlerts=0
  $wordExporter.AutomationSecurity=3
  foreach($file in $files){
    if($Only -and [IO.Path]::GetFileNameWithoutExtension($file) -ne $Only){continue}
    $openedDoc=$null
    try{
      $full=Join-Path $projectRoot $file
      $openedDoc=$wordExporter.Documents.Open($full,$false,$true,$false)
      $openedDoc.Repaginate()
      $pdf=Join-Path $pdfDir (([IO.Path]::GetFileNameWithoutExtension($file))+'.pdf')
      $openedDoc.ExportAsFixedFormat($pdf,17)
      Write-Output ($file+' pages='+$openedDoc.ComputeStatistics(2))
    }finally{if($null-ne $openedDoc){$openedDoc.Close(0)}}
  }
}finally{if($null-ne $wordExporter){$wordExporter.Quit(0)}}
