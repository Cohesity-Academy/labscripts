# ==========================
# Home Drive Generator
# PowerShell 5.1 Compatible
# Target: ~10 GB, ~100 users
# ==========================

$RootPath = "\\isilon\HomeDrive"
$UserCount = 100
$TargetSizeGB = 10
$TargetBytes = $TargetSizeGB * 1GB
$Global:CurrentSize = 0

$TopFolders = @(
    "Desktop",
    "Documents",
    "Downloads",
    "Pictures",
    "Projects"
)

$SubFolders = @(
    "Work",
    "Personal",
    "Archive",
    "Old",
    "Misc"
)

$FileExtensions = @(
    ".docx",".xlsx",".pptx",".pdf",
    ".txt",".csv",".jpg",".png",
    ".zip",".log"
)

# Create root
if (-not (Test-Path $RootPath)) {
    New-Item -ItemType Directory -Path $RootPath | Out-Null
}

function New-UserFile {
    param (
        [string]$Path
    )

    if ($Global:CurrentSize -ge $TargetBytes) { return }

    $ext = Get-Random -InputObject $FileExtensions
    $name = "File_" + (Get-Random -Minimum 1000 -Maximum 9999) + $ext
    $file = Join-Path $Path $name

    # Size: 1–25 MB (smaller per-user footprint)
    $sizeMB = Get-Random -Minimum 1 -Maximum 26
    $sizeBytes = $sizeMB * 1MB

    # Prevent overshoot
    if (($Global:CurrentSize + $sizeBytes) -gt $TargetBytes) {
        $sizeBytes = $TargetBytes - $Global:CurrentSize
    }

    $buffer = New-Object byte[] (1MB)
    $rng = New-Object System.Random
    $fs = New-Object System.IO.FileStream($file, [System.IO.FileMode]::Create)

    $written = 0
    while ($written -lt $sizeBytes) {
        $rng.NextBytes($buffer)
        $writeSize = [Math]::Min($buffer.Length, $sizeBytes - $written)
        $fs.Write($buffer, 0, $writeSize)
        $written += $writeSize
    }
    $fs.Close()

    # Randomize timestamp (last 6 months)
    (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-(Get-Random -Minimum 1 -Maximum 180))

    $Global:CurrentSize += $sizeBytes
}

for ($u = 1; $u -le $UserCount; $u++) {
    if ($Global:CurrentSize -ge $TargetBytes) { break }

    $userName = "user" + ("{0:D3}" -f $u)
    $userPath = Join-Path $RootPath $userName
    New-Item -ItemType Directory -Path $userPath -Force | Out-Null

    foreach ($folder in $TopFolders) {
        if ($Global:CurrentSize -ge $TargetBytes) { break }

        $topPath = Join-Path $userPath $folder
        New-Item -ItemType Directory -Path $topPath -Force | Out-Null

        # Random subset of subfolders
        $subCount = Get-Random -Minimum 1 -Maximum 4
        $chosenSubs = Get-Random -InputObject $SubFolders -Count $subCount

        foreach ($sub in $chosenSubs) {
            if ($Global:CurrentSize -ge $TargetBytes) { break }

            $subPath = Join-Path $topPath $sub
            New-Item -ItemType Directory -Path $subPath -Force | Out-Null

            # 1–4 files per subfolder
            $fileCount = Get-Random -Minimum 1 -Maximum 5
            for ($f = 1; $f -le $fileCount; $f++) {
                New-UserFile -Path $subPath
            }
        }
    }
}

Write-Host "Home drive data created at $RootPath"
Write-Host ("Total size generated: {0:N2} GB" -f ($Global:CurrentSize / 1GB))
