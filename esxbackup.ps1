<#
Backup-Lab-AutoModules.ps1
PowerShell 5.1 compatible
- Auto-installs required modules/providers
- Backs up ESXi configs via SSH
- Starts VCSA file-based backup via VAMI API
#>

param(
    [string] $VCSA = "192.168.1.50",
    [string[]] $ESXiHosts = @("192.168.1.51","192.168.1.52"),
    [string] $LocalBackupRoot = "C:\VMwareBackups",
    [string] $VcsaBackupLocation = "scp://backupserver:/backups/vcsa",
    [ValidateSet("config","all")]
    [string] $VcsaBackupParts = "config",
    [string] $BackupComment = "Lab config backup"
)

# -------------------------------------------------
# Environment Hardening (PS 5.1)
# -------------------------------------------------

Write-Host "Configuring TLS 1.2..." -ForegroundColor Cyan
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {}

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

# -------------------------------------------------
# Ensure NuGet + PowerShellGet + Posh-SSH
# -------------------------------------------------

function Ensure-NuGet {
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Write-Host "Installing NuGet provider..." -ForegroundColor Yellow
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
    }
}

function Ensure-PowerShellGet {
    if (-not (Get-Module -ListAvailable -Name PowerShellGet)) {
        Write-Host "Installing PowerShellGet..." -ForegroundColor Yellow
        Install-Module -Name PowerShellGet -Scope CurrentUser -Force
    }
}

function Ensure-PoshSSH {
    if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
        Write-Host "Installing Posh-SSH..." -ForegroundColor Yellow
        Install-Module -Name Posh-SSH -Scope CurrentUser -Force
    }
    Import-Module Posh-SSH -ErrorAction Stop
}

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

Ensure-NuGet
Ensure-PowerShellGet
Ensure-PoshSSH

# -------------------------------------------------
# Utility Functions
# -------------------------------------------------

function Ensure-Folder($Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function New-BasicAuthHeader($Cred) {
    $pair = "$($Cred.UserName):$($Cred.GetNetworkCredential().Password)"
    $bytes = [Text.Encoding]::UTF8.GetBytes($pair)
    $b64 = [Convert]::ToBase64String($bytes)
    return @{ Authorization = "Basic $b64" }
}

# -------------------------------------------------
# ESXi Backup
# -------------------------------------------------

function Backup-ESXi {
    param($HostIP, $Cred, $OutDir)

    Write-Host "`n[ESXi] Backing up $HostIP..." -ForegroundColor Cyan

    $session = New-SSHSession -ComputerName $HostIP -Credential $Cred -AcceptKey -ErrorAction Stop
    try {
        $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "vim-cmd hostsvc/firmware/backup_config"
        $text = $result.Output -join "`n"
        $url = [regex]::Match($text, 'https?://\S+').Value

        if (-not $url) { throw "Backup URL not found in output." }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $outfile = Join-Path $OutDir "esxi-$($HostIP.Replace('.','-'))-$timestamp.tgz"

        $authPair = "$($Cred.UserName):$($Cred.GetNetworkCredential().Password)"
        $authB64  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($authPair))
        $headers  = @{ Authorization = "Basic $authB64" }

        Invoke-WebRequest -Uri $url -Headers $headers -OutFile $outfile -UseBasicParsing

        Write-Host "[ESXi] Saved: $outfile" -ForegroundColor Green
        return $outfile
    }
    finally {
        Remove-SSHSession -SessionId $session.SessionId | Out-Null
    }
}

# -------------------------------------------------
# VCSA Backup
# -------------------------------------------------

function Start-VCSA-Backup {
    param($VcsaIP, $VamiCred, $StorageCred, $Location, $Parts, $EncPass)

    $headers = New-BasicAuthHeader $VamiCred
    $url = "https://$VcsaIP`:5480/rest/appliance/recovery/backup/job"

    $body = @{
        parts = @($Parts)
        location_type = "scp"
        location = $Location
        comment = $BackupComment
        username = $StorageCred.UserName
        password = $StorageCred.GetNetworkCredential().Password
        encryption_password = $EncPass
    } | ConvertTo-Json -Depth 5

    Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body -ContentType "application/json"
}

function Get-VCSA-BackupStatus {
    param($VcsaIP, $VamiCred, $JobId)
    $headers = New-BasicAuthHeader $VamiCred
    $url = "https://$VcsaIP`:5480/rest/appliance/recovery/backup/job/$JobId"
    Invoke-RestMethod -Method Get -Uri $url -Headers $headers
}

# -------------------------------------------------
# Main
# -------------------------------------------------

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$EsxiDir = Join-Path $LocalBackupRoot "ESXi\$timestamp"
Ensure-Folder $EsxiDir

Write-Host "`nEnter ESXi SSH credentials (root)" -ForegroundColor Yellow
$esxiCred = Get-Credential

Write-Host "Enter VCSA VAMI credentials (root on port 5480)" -ForegroundColor Yellow
$vcsaCred = Get-Credential

Write-Host "Enter SCP backup server credentials" -ForegroundColor Yellow
$storageCred = Get-Credential

$encSecure = Read-Host "Enter encryption password for VCSA backup archive" -AsSecureString
$encPass = (New-Object System.Net.NetworkCredential("", $encSecure)).Password

# ESXi backups
foreach ($host in $ESXiHosts) {
    try {
        Backup-ESXi -HostIP $host -Cred $esxiCred -OutDir $EsxiDir
    }
    catch {
        Write-Error "[ESXi] $host failed: $($_.Exception.Message)"
    }
}

# VCSA backup
Write-Host "`nStarting VCSA file-based backup..." -ForegroundColor Cyan
$response = Start-VCSA-Backup -VcsaIP $VCSA -VamiCred $vcsaCred -StorageCred $storageCred -Location $VcsaBackupLocation -Parts $VcsaBackupParts -EncPass $encPass

$jobId = $response.id
Write-Host "VCSA Backup Job ID: $jobId" -ForegroundColor Green

while ($true) {
    Start-Sleep 10
    $status = Get-VCSA-BackupStatus -VcsaIP $VCSA -VamiCred $vcsaCred -JobId $jobId
    Write-Host ("[{0}] State={1} Progress={2}" -f (Get-Date), $status.state, $status.progress)
    if ($status.state -match "SUCCEEDED|FAILED|CANCELED") { break }
}

Write-Host "`nBackup process complete." -ForegroundColor Cyan
