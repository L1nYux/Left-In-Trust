param(
    [Parameter(Mandatory = $true)]
    [string]$Destination
)

$ErrorActionPreference = "Stop"
$version = "4.7.2.stable"
$url = "https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=export_templates.tpz&platform=templates"
$wanted = @(
    "windows_debug_x86_64.exe",
    "windows_debug_x86_64_console.exe",
    "windows_release_x86_64.exe",
    "windows_release_x86_64_console.exe"
)

function Read-U16([byte[]]$Buffer, [int]$Offset) {
    return [BitConverter]::ToUInt16($Buffer, $Offset)
}

function Read-U32([byte[]]$Buffer, [int]$Offset) {
    return [BitConverter]::ToUInt32($Buffer, $Offset)
}

function Get-RangeResponse([System.Net.Http.HttpClient]$Client, [long]$Start, [long]$End) {
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $url)
    $request.Headers.Range = [System.Net.Http.Headers.RangeHeaderValue]::new($Start, $End)
    $response = $Client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    if ([int]$response.StatusCode -ne 206) {
        $response.Dispose()
        throw "Server did not honor byte range $Start-$End"
    }
    return $response
}

$resolvedDestination = [System.IO.Path]::GetFullPath($Destination)
[System.IO.Directory]::CreateDirectory($resolvedDestination) | Out-Null
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromMinutes(20)

try {
    $head = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, $url)
    $headResponse = $client.SendAsync($head).GetAwaiter().GetResult()
    $headResponse.EnsureSuccessStatusCode() | Out-Null
    $fileSize = $headResponse.Content.Headers.ContentLength
    $headResponse.Dispose()
    if (-not $fileSize) { throw "Template archive did not report a size" }

    $tailStart = [Math]::Max(0, $fileSize - 65536)
    $tailResponse = Get-RangeResponse $client $tailStart ($fileSize - 1)
    $tail = $tailResponse.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
    $tailResponse.Dispose()

    $eocd = -1
    for ($index = $tail.Length - 22; $index -ge 0; $index--) {
        if ((Read-U32 $tail $index) -eq 0x06054b50) { $eocd = $index; break }
    }
    if ($eocd -lt 0) { throw "Cannot find ZIP central directory" }

    $entryCount = Read-U16 $tail ($eocd + 10)
    $centralOffset = Read-U32 $tail ($eocd + 16)
    $cursor = [int]($centralOffset - $tailStart)
    $entries = @{}
    for ($entryIndex = 0; $entryIndex -lt $entryCount; $entryIndex++) {
        if ((Read-U32 $tail $cursor) -ne 0x02014b50) { throw "Invalid central directory record" }
        $method = Read-U16 $tail ($cursor + 10)
        $compressedSize = Read-U32 $tail ($cursor + 20)
        $uncompressedSize = Read-U32 $tail ($cursor + 24)
        $nameLength = Read-U16 $tail ($cursor + 28)
        $extraLength = Read-U16 $tail ($cursor + 30)
        $commentLength = Read-U16 $tail ($cursor + 32)
        $localOffset = Read-U32 $tail ($cursor + 42)
        $entryName = [Text.Encoding]::UTF8.GetString($tail, $cursor + 46, $nameLength)
        $shortName = [System.IO.Path]::GetFileName($entryName)
        if ($wanted -contains $shortName) {
            $entries[$shortName] = @{
                Method = $method
                CompressedSize = [long]$compressedSize
                UncompressedSize = [long]$uncompressedSize
                LocalOffset = [long]$localOffset
            }
        }
        $cursor += 46 + $nameLength + $extraLength + $commentLength
    }

    foreach ($name in $wanted) {
        if (-not $entries.ContainsKey($name)) { throw "Template not found in archive: $name" }
        $entry = $entries[$name]
        $headerResponse = Get-RangeResponse $client $entry.LocalOffset ($entry.LocalOffset + 29)
        $localHeader = $headerResponse.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        $headerResponse.Dispose()
        if ((Read-U32 $localHeader 0) -ne 0x04034b50) { throw "Invalid local header for $name" }
        $localNameLength = Read-U16 $localHeader 26
        $localExtraLength = Read-U16 $localHeader 28
        $dataStart = $entry.LocalOffset + 30 + $localNameLength + $localExtraLength
        $dataEnd = $dataStart + $entry.CompressedSize - 1
        $temporary = Join-Path $resolvedDestination "$name.deflate.part"
        $output = Join-Path $resolvedDestination $name
        Write-Host "Downloading $name ($($entry.CompressedSize) compressed bytes)"
        $dataResponse = Get-RangeResponse $client $dataStart $dataEnd
        $sourceStream = $dataResponse.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $temporaryStream = [System.IO.File]::Create($temporary)
        try { $sourceStream.CopyTo($temporaryStream) } finally { $temporaryStream.Dispose(); $sourceStream.Dispose(); $dataResponse.Dispose() }

        $compressedStream = [System.IO.File]::OpenRead($temporary)
        $outputStream = [System.IO.File]::Create($output)
        try {
            if ($entry.Method -eq 0) {
                $compressedStream.CopyTo($outputStream)
            } elseif ($entry.Method -eq 8) {
                $deflate = [System.IO.Compression.DeflateStream]::new($compressedStream, [System.IO.Compression.CompressionMode]::Decompress, $true)
                try { $deflate.CopyTo($outputStream) } finally { $deflate.Dispose() }
            } else {
                throw "Unsupported ZIP method $($entry.Method) for $name"
            }
        } finally {
            $outputStream.Dispose()
            $compressedStream.Dispose()
        }
        Remove-Item -LiteralPath $temporary
        $actualLength = (Get-Item -LiteralPath $output).Length
        if ($actualLength -ne $entry.UncompressedSize) { throw "Size mismatch for $name" }
        Write-Host "Installed $name ($actualLength bytes)"
    }
    [System.IO.File]::WriteAllText((Join-Path $resolvedDestination "version.txt"), "$version`n", [System.Text.UTF8Encoding]::new($false))
    Write-Host "Windows x86_64 templates installed in $resolvedDestination"
} finally {
    $client.Dispose()
}
