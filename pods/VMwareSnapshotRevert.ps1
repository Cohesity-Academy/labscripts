# ===============================
# Configuration
# ===============================

$vCenter  = "vcenter.acme.com"
$Username = "administrator@acme.com"
$Password = "Acme123!"

$VMNames = @(
    "AD-Server-1",
    "App-Server-1",
    "Cohesity-esx",
    "Isilon",
    "MSSQL-Server-1",
    "NFS-Server-1"
)

# ===============================
# TLS 1.2 for older hosts
# ===============================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ===============================
# Install VMware PowerCLI if missing (silent)
# ===============================
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {

    Write-Host "Installing VMware PowerCLI..." -ForegroundColor Yellow

    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    }

    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    Install-Module VMware.PowerCLI `
        -Scope CurrentUser `
        -Force `
        -AllowClobber `
        -Confirm:$false
}

Import-Module VMware.PowerCLI

# ===============================
# PowerCLI global configuration
# ===============================

# Disable CEIP prompt
Set-PowerCLIConfiguration `
    -Scope User `
    -ParticipateInCEIP $false `
    -Confirm:$false | Out-Null

# Ignore invalid/self-signed certificates
Set-PowerCLIConfiguration `
    -Scope User `
    -InvalidCertificateAction Ignore `
    -Confirm:$false | Out-Null

# ===============================
# Connect to vCenter
# ===============================
Connect-VIServer `
    -Server $vCenter `
    -User $Username `
    -Password $Password

# ===============================
# Revert snapshots and power on
# ===============================
foreach ($vmName in $VMNames) {

    Write-Host "Processing $vmName" -ForegroundColor Cyan

    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if ($vm -eq $null) {
        Write-Warning "VM not found: $vmName"
        continue
    }

    $snapshot = Get-Snapshot -VM $vm |
        Sort-Object Created -Descending |
        Select-Object -First 1

    if ($snapshot -eq $null) {
        Write-Warning "No snapshots found for $vmName"
        continue
    }

    Write-Host "Reverting to snapshot '$($snapshot.Name)'" -ForegroundColor Yellow
    Set-VM -VM $vm -Snapshot $snapshot -Confirm:$false

    # Refresh VM state
    $vm = Get-VM -Name $vmName

    if ($vm.PowerState -ne "PoweredOn") {
        Write-Host "Powering on $vmName" -ForegroundColor Green
        Start-VM -VM $vm -Confirm:$false | Out-Null
    }
}

# ===============================
# Disconnect
# ===============================
Disconnect-VIServer -Server $vCenter -Confirm:$false
