# ==========================
# Application Server SMB Incremental Changes
# PowerShell 5.1 Compatible
# ==========================

$RootPath = "s:\"

# --------------------------
# LOG FILE CHANGES (heavy)
# --------------------------
$logFiles = Get-ChildItem -Path (Join-Path $RootPath "logs") -Recurse -File -ErrorAction SilentlyContinue

foreach ($file in $logFiles) {
    # Append 10–100 KB
    $appendKB = Get-Random -Minimum 100 -Maximum 1010
    $buffer = New-Object byte[] ($appendKB * 1KB)
    (New-Object System.Random).NextBytes($buffer)

    $fs = New-Object System.IO.FileStream(
        $file.FullName,
        [System.IO.FileMode]::Append,
        [System.IO.FileAccess]::Write
    )
    $fs.Write($buffer, 0, $buffer.Length)
    $fs.Close()

    $file.LastWriteTime = Get-Date
}

# --------------------------
# TEMP FILE CHURN
# --------------------------
$tempPath = Join-Path $RootPath "temp"
if (Test-Path $tempPath) {

    # Delete some temp files
    Get-ChildItem -Path $tempPath -Recurse -File |
        Get-Random -Count 5 |
        Remove-Item -Force -ErrorAction SilentlyContinue

    # Create new temp files
    for ($i = 1; $i -le 10; $i++) {
        $fileName = "temp_" + (Get-Date -Format "yyyyMMdd_HHmmss") + "_" + $i + ".tmp"
        $filePath = Join-Path $tempPath "working\$fileName"

        $sizeMB = Get-Random -Minimum 5 -Maximum 21
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

# --------------------------
# APPDATA MINIMAL CHANGES
# --------------------------
$appDataFiles = Get-ChildItem -Path (Join-Path $RootPath "appdata") -Recurse -File -ErrorAction SilentlyContinue |
    Get-Random -Count 3

foreach ($file in $appDataFiles) {
    # Small append (rare)
    $buffer = New-Object byte[] (512KB)
    (New-Object System.Random).NextBytes($buffer)

    $fs = New-Object System.IO.FileStream(
        $file.FullName,
        [System.IO.FileMode]::Append,
        [System.IO.FileAccess]::Write
    )
    $fs.Write($buffer, 0, $buffer.Length)
    $fs.Close()

    $file.LastWriteTime = Get-Date
}

Write-Host "Application server SMB incremental changes complete."
.\AppChangeSimulator.ps1