# ==========================
# Cohesity File-Level Backup Lab Generator
# PowerShell 5.1 Compatible
# Target Size: ~50 GB
# ==========================

$RootPath = "\\isilon\GroupDrive"
$TargetSizeGB = 50
$TargetBytes = $TargetSizeGB * 1GB
$Global:CurrentSize = 0

$Departments = @{
    "Finance"      = @("Budgets","Payroll","Invoices","Audits")
    "HR"           = @("Employees","Onboarding","Policies","Benefits")
    "IT"           = @("Projects","Infrastructure","Security","Backups")
    "Legal"        = @("Contracts","Compliance","Litigation")
    "Sales"        = @("Leads","Accounts","Quotes","Forecasts")
    "Marketing"    = @("Campaigns","Brand","Social","Analytics")
    "Operations"   = @("Vendors","Logistics","Reports")
    "Engineering" = @("Designs","Specs","Testing","Releases")
    "Executive"   = @("Board","Strategy","Financials")
}

$FileExtensions = @(
    ".docx",".xlsx",".pptx",".pdf",
    ".csv",".log",".zip",".json",".xml"
)

$NameFragments = @(
    "Final","Draft","v2","Approved","Review",
    "2022","2023","2024","Q1","Q2","Q3","Q4",
    "Updated","Confidential","Internal"
)

# Ensure root exists
if (-not (Test-Path $RootPath)) {
    New-Item -ItemType Directory -Path $RootPath | Out-Null
}

function New-RandomFile {
    param (
        [string]$Path
    )

    if ($Global:CurrentSize -ge $TargetBytes) {
        return
    }

    $ext = Get-Random -InputObject $FileExtensions
    $name = (Get-Random -InputObject $NameFragments) + "_" + (Get-Random -Minimum 1000 -Maximum 9999) + $ext
    $file = Join-Path $Path $name

    # Size: 10–100 MB
    $sizeMB = Get-Random -Minimum 10 -Maximum 101
    $sizeBytes = $sizeMB * 1MB

    # Prevent overshoot
    if (($Global:CurrentSize + $sizeBytes) -gt $TargetBytes) {
        $sizeBytes = $TargetBytes - $Global:CurrentSize
    }

    $bufferSize = 4MB
    $buffer = New-Object byte[] $bufferSize
    $rng = New-Object System.Random
    $fs = New-Object System.IO.FileStream($file, [System.IO.FileMode]::Create)

    try {
        $written = 0
        while ($written -lt $sizeBytes) {
            $rng.NextBytes($buffer)
            $writeSize = [Math]::Min($bufferSize, $sizeBytes - $written)
            $fs.Write($buffer, 0, $writeSize)
            $written += $writeSize
        }
    }
    finally {
        $fs.Close()
    }

    # Randomize last modified time (1–365 days ago)
    $daysBack = Get-Random -Minimum 1 -Maximum 366
    (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-$daysBack)

    $Global:CurrentSize += $sizeBytes
}

foreach ($dept in $Departments.Keys) {
    if ($Global:CurrentSize -ge $TargetBytes) { break }

    $deptPath = Join-Path $RootPath $dept
    if (-not (Test-Path $deptPath)) {
        New-Item -ItemType Directory -Path $deptPath | Out-Null
    }

    foreach ($sub in $Departments[$dept]) {
        if ($Global:CurrentSize -ge $TargetBytes) { break }

        $currentPath = Join-Path $deptPath $sub
        if (-not (Test-Path $currentPath)) {
            New-Item -ItemType Directory -Path $currentPath | Out-Null
        }

        # Depth: 2–5
        $depth = Get-Random -Minimum 2 -Maximum 6
        for ($i = 1; $i -le $depth; $i++) {
            if ($Global:CurrentSize -ge $TargetBytes) { break }

            $folderName = "Folder_" + (Get-Random -Minimum 100 -Maximum 999)
            $currentPath = Join-Path $currentPath $folderName
            if (-not (Test-Path $currentPath)) {
                New-Item -ItemType Directory -Path $currentPath | Out-Null
            }

            # Files per folder: 1–4
            $fileCount = Get-Random -Minimum 1 -Maximum 5
            for ($f = 1; $f -le $fileCount; $f++) {
                New-RandomFile -Path $currentPath
            }
        }
    }
}

Write-Host "Cohesity file-level lab data created at $RootPath"
Write-Host ("Total size generated: {0:N2} GB" -f ($Global:CurrentSize / 1GB))
