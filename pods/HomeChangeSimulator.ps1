# ==========================
# Home Drive Incremental Change Simulator
# PowerShell 5.1 Compatible
# ==========================

$RootPath = "\\isilon\HomeDrive"

# Tuning knobs
$ChangePercent     = 15   # % of existing files to modify
$NewFilesPerUser   = 1    # New files per user per run

# --------------------------
# Get all existing files
# --------------------------
$allFiles = Get-ChildItem -Path $RootPath -Recurse -File -ErrorAction SilentlyContinue

if (-not $allFiles -or $allFiles.Count -eq 0) {
    Write-Host "No files found under $RootPath"
    return
}

# --------------------------
# Modify existing files
# --------------------------
$modifyCount = [Math]::Ceiling($allFiles.Count * ($ChangePercent / 100))
$filesToModify = Get-Random -InputObject $allFiles -Count $modifyCount

foreach ($file in $filesToModify) {
    try {
        # Append 2–12 KB (block-level change)
        $appendKB = Get-Random -Minimum 2 -Maximum 13
        $buffer = New-Object byte[] ($appendKB * 1KB)
        (New-Object System.Random).NextBytes($buffer)

        $fs = New-Object System.IO.FileStream(
            $file.FullName,
            [System.IO.FileMode]::Append,
            [System.IO.FileAccess]::Write
        )

        $fs.Write($buffer, 0, $buffer.Length)
        $fs.Close()

        # Update timestamp
        $file.LastWriteTime = Get-Date
    }
    catch {
        Write-Warning "Failed to modify $($file.FullName)"
    }
}

# --------------------------
# Add new files (Downloads)
# --------------------------
$downloadFolders = Get-ChildItem -Path $RootPath -Recurse -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq "Downloads" }

foreach ($dl in $downloadFolders) {
    for ($i = 1; $i -le $NewFilesPerUser; $i++) {

        $fileName = "Download_" +
            (Get-Date -Format "yyyyMMdd_HHmmss") +
            "_" + (Get-Random -Minimum 100 -Maximum 999) +
            ".zip"

        $filePath = Join-Path $dl.FullName $fileName

        # New file size: 5–30 MB
        $sizeMB = Get-Random -Minimum 5 -Maximum 31
        $sizeBytes = $sizeMB * 1MB

        $buffer = New-Object byte[] (2MB)
        $rng = New-Object System.Random
        $fs = New-Object System.IO.FileStream(
            $filePath,
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
    }
}

Write-Host "Home drive incremental changes complete."
Write-Host ("Files modified: {0}" -f $modifyCount)
Write-Host ("New files created per user: {0}" -f $NewFilesPerUser)
