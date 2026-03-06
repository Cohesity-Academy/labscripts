# ==========================
# Cohesity Incremental Change Simulator
# PowerShell 5.1 Compatible
# ==========================

$RootPath = "\\isilon\GroupDrive"
$ChangePercent = 7     # % of files to modify
$NewFileCount = 10     # New files per run

# Get all files
$allFiles = Get-ChildItem -Path $RootPath -Recurse -File

if ($allFiles.Count -eq 0) {
    Write-Host "No files found to modify."
    return
}

# ---- Modify existing files ----
$modifyCount = [Math]::Ceiling($allFiles.Count * ($ChangePercent / 100))
$filesToModify = Get-Random -InputObject $allFiles -Count $modifyCount

foreach ($file in $filesToModify) {
    try {
        # Append 4–16 KB (block-level realistic change)
        $appendKB = Get-Random -Minimum 4 -Maximum 17
        $buffer = New-Object byte[] ($appendKB * 1KB)
        (New-Object System.Random).NextBytes($buffer)

        $fs = New-Object System.IO.FileStream(
            $file.FullName,
            [System.IO.FileMode]::Append
        )
        $fs.Write($buffer, 0, $buffer.Length)
        $fs.Close()

        # Update modified time
        $file.LastWriteTime = Get-Date
    }
    catch {
        Write-Warning "Could not modify $($file.FullName)"
    }
}

# ---- Add new files ----
$folders = Get-ChildItem -Path $RootPath -Recurse -Directory
$extensions = ".docx",".xlsx",".pdf",".csv",".log"

for ($i = 1; $i -le $NewFileCount; $i++) {
    $folder = Get-Random -InputObject $folders
    $ext = Get-Random -InputObject $extensions
    $fileName = "NewFile_" + (Get-Date -Format yyyyMMdd_HHmmss) + "_" + $i + $ext
    $filePath = Join-Path $folder.FullName $fileName

    # New file size: 5–20 MB
    $sizeMB = Get-Random -Minimum 5 -Maximum 21
    $sizeBytes = $sizeMB * 1MB

    $buffer = New-Object byte[] (2MB)
    $rng = New-Object System.Random
    $fs = New-Object System.IO.FileStream($filePath, [System.IO.FileMode]::Create)

    $written = 0
    while ($written -lt $sizeBytes) {
        $rng.NextBytes($buffer)
        $writeSize = [Math]::Min($buffer.Length, $sizeBytes - $written)
        $fs.Write($buffer, 0, $writeSize)
        $written += $writeSize
    }
    $fs.Close()
}

# ---- Optional: delete a few files (commented out) ----
# $deleteCount = 3
# Get-Random -InputObject $allFiles -Count $deleteCount | Remove-Item -Force

Write-Host "Incremental change simulation complete."
