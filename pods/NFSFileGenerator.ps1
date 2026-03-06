# ==========================
# NFS Server Data Generator
# PowerShell 5.1 Compatible
# ==========================

$RootPath = "d:\nfs"     # Change to your mounted NFS path
$TargetSizeGB = 15
$TargetBytes = $TargetSizeGB * 1GB
$Global:CurrentSize = 0

$Exports = @(
    "projects",
    "appdata",
    "logs",
    "shared",
    "backups"
)

$FileExtensions = @(
    ".log",".cfg",".conf",".dat",".bin",
    ".tar",".gz",".sh",".py",".json"
)

# Ensure root
if (-not (Test-Path $RootPath)) {
    New-Item -ItemType Directory -Path $RootPath | Out-Null
}

function New-NfsFile {
    param (
        [string]$Path
    )

    if ($Global:CurrentSize -ge $TargetBytes) { return }

    $ext = Get-Random -InputObject $FileExtensions
    $name = "file_" + (Get-Random -Minimum 10000 -Maximum 99999) + $ext
    $file = Join-Path $Path $name

    # Size: 5–500 MB (NFS-style large files)
    $sizeMB = Get-Random -Minimum 5 -Maximum 501
    $sizeBytes = $sizeMB * 1MB

    if (($Global:CurrentSize + $sizeBytes) -gt $TargetBytes) {
        $sizeBytes = $TargetBytes - $Global:CurrentSize
    }

    $buffer = New-Object byte[] (4MB)
    $rng = New-Object System.Random
    $fs = New-Object System.IO.FileStream(
        $file,
        [System.IO.FileMode]::Create,
        [System.IO.FileAccess]::Write
    )

    $written = 0
    while ($written -lt $sizeBytes) {
        $rng.NextBytes($buffer)
        $writeSize = [Math]::Min($buffer.Length, $sizeBytes - $written)
        $fs.Write($buffer, 0, $writeSize)
        $written += $writeSize
    }
    $fs.Close()

    # NFS-style timestamps (older, stable data)
    (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-(Get-Random -Minimum 10 -Maximum 730))

    $Global:CurrentSize += $sizeBytes
}

foreach ($export in $Exports) {
    if ($Global:CurrentSize -ge $TargetBytes) { break }

    $exportPath = Join-Path $RootPath $export
    New-Item -ItemType Directory -Path $exportPath -Force | Out-Null

    # Depth: 3–7 (deep trees common on NFS)
    $depth = Get-Random -Minimum 3 -Maximum 8
    $currentPath = $exportPath

    for ($d = 1; $d -le $depth; $d++) {
        if ($Global:CurrentSize -ge $TargetBytes) { break }

        $folderName = "dir_" + (Get-Random -Minimum 100 -Maximum 999)
        $currentPath = Join-Path $currentPath $folderName
        New-Item -ItemType Directory -Path $currentPath -Force | Out-Null

        # Files per directory: 1–3 (large files)
        $fileCount = Get-Random -Minimum 1 -Maximum 4
        for ($f = 1; $f -le $fileCount; $f++) {
            New-NfsFile -Path $currentPath
        }
    }
}

Write-Host "NFS data created at $RootPath"
Write-Host ("Total size generated: {0:N2} GB" -f ($Global:CurrentSize / 1GB))