# ==========================
# Application Server SMB Data Generator
# PowerShell 5.1 Compatible
# ==========================

$RootPath = "\\App-server-1\AppShares"
$TargetSizeGB = 35
$TargetBytes = $TargetSizeGB * 1GB
$Global:CurrentSize = 0

$Shares = @{
    "appdata" = @("prod","test","archive")
    "logs"    = @("app1","app2","app3")
    "config"  = @("current","backup")
    "exports" = @("daily","monthly")
    "temp"    = @("working")
}

$FileTypes = @{
    "appdata" = @(".dat",".bin")
    "logs"    = @(".log")
    "config"  = @(".cfg",".conf",".json")
    "exports" = @(".csv",".zip",".tar")
    "temp"    = @(".tmp",".dat")
}

# Ensure root
if (-not (Test-Path $RootPath)) {
    New-Item -ItemType Directory -Path $RootPath | Out-Null
}

function New-AppFile {
    param (
        [string]$Path,
        [string[]]$Extensions,
        [int]$MinMB,
        [int]$MaxMB
    )

    if ($Global:CurrentSize -ge $TargetBytes) { return }

    $ext = Get-Random -InputObject $Extensions
    $name = "file_" + (Get-Random -Minimum 10000 -Maximum 99999) + $ext
    $file = Join-Path $Path $name

    $sizeMB = Get-Random -Minimum $MinMB -Maximum ($MaxMB + 1)
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

    # App servers have older, stable data
    (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-(Get-Random -Minimum 5 -Maximum 365))

    $Global:CurrentSize += $sizeBytes
}

foreach ($share in $Shares.Keys) {
    if ($Global:CurrentSize -ge $TargetBytes) { break }

    $sharePath = Join-Path $RootPath $share
    New-Item -ItemType Directory -Path $sharePath -Force | Out-Null

    foreach ($sub in $Shares[$share]) {
        if ($Global:CurrentSize -ge $TargetBytes) { break }

        $subPath = Join-Path $sharePath $sub
        New-Item -ItemType Directory -Path $subPath -Force | Out-Null

        # Files per folder
        $fileCount = Get-Random -Minimum 5 -Maximum 16

        for ($i = 1; $i -le $fileCount; $i++) {
            switch ($share) {
                "logs"    { New-AppFile $subPath $FileTypes["logs"]    1 10  }
                "config"  { New-AppFile $subPath $FileTypes["config"]  1 2   }
                "exports" { New-AppFile $subPath $FileTypes["exports"] 10 50 }
                "temp"    { New-AppFile $subPath $FileTypes["temp"]    5 25  }
                default   { New-AppFile $subPath $FileTypes["appdata"] 25 250 }
            }
        }
    }
}

Write-Host "Application server SMB data created at $RootPath"
Write-Host ("Total size generated: {0:N2} GB" -f ($Global:CurrentSize / 1GB))
