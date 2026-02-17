#requires -Version 5.1

<#
Purpose:
- Connect to vCenter
- Ensure Datacenter + Cluster exist
- Add ESXi hosts
- Register any VMs found on datastores by scanning for *.vmx files

Lab credentials are embedded in clear text per request.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -----------------------------
# Lab configuration (EDIT HERE)
# -----------------------------
$vCenter         = "vcenter.cohesitylabs.az"
$vCenterUser     = "administrator@vsphere.local"
$vCenterPassword = "Cohesity123!"

$esxiUser        = "root"
$esxiPassword    = "Cohesity123!"

$DatacenterName  = "DC1"
$ClusterName     = "Cluster1"

$Hosts = @(
    "ESXi-Host1.cohesitylabs.az",
    "ESXi-Host2.cohesitylabs.az"
)

# If you ONLY want specific local datastore(s), set these names.
# If left empty, script scans ALL accessible datastores on each host.
$OnlyDatastores = @(
    # "datastore1"
)

# Dry-run mode: set to $true to not make changes
$WhatIf = $false

# -----------------------------
# PowerCLI install / import
# -----------------------------
function Ensure-NuGetProvider {
    $prov = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    if (-not $prov) {
        Write-Host "Installing NuGet package provider..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
    }
}

function Ensure-PowerCLI {
    if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
        Write-Host "VMware.PowerCLI not found. Installing from PSGallery..."
        # Make PSGallery trusted to avoid prompts (lab convenience)
        try {
            $psg = Get-PSRepository -Name "PSGallery" -ErrorAction Stop
            if ($psg.InstallationPolicy -ne "Trusted") {
                Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
            }
        } catch {
            # If repository doesn't exist for some reason, register it
            Register-PSRepository -Default -ErrorAction SilentlyContinue
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        }

        Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Force -AllowClobber
    }

    Import-Module VMware.PowerCLI -ErrorAction Stop

    # Lab convenience: ignore invalid cert prompts
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null
}

# -----------------------------
# Helpers
# -----------------------------
function New-PlainCredential {
    param(
        [Parameter(Mandatory=$true)][string]$User,
        [Parameter(Mandatory=$true)][string]$Password
    )
    $sec = ConvertTo-SecureString $Password -AsPlainText -Force
    New-Object System.Management.Automation.PSCredential ($User, $sec)
}

function Ensure-Datacenter {
    param([string]$Name)

    $dc = Get-Datacenter -Name $Name -ErrorAction SilentlyContinue
    if ($dc) {
        Write-Host "Datacenter exists: $Name"
        return $dc
    }

    if ($script:WhatIf) {
        Write-Host "WhatIf: would create Datacenter '$Name'"
        return $null
    }

    $dc = New-Datacenter -Name $Name
    Write-Host "Created Datacenter: $Name"
    return $dc
}

function Ensure-Cluster {
    param(
        [string]$Name,
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.DatacenterImpl]$Datacenter
    )

    $cluster = Get-Cluster -Name $Name -ErrorAction SilentlyContinue
    if ($cluster) {
        Write-Host "Cluster exists: $Name"
        return $cluster
    }

    if ($script:WhatIf) {
        Write-Host "WhatIf: would create Cluster '$Name' in '$($Datacenter.Name)'"
        return $null
    }

    # Defaulting HA/DRS off to keep a clean lab baseline; flip on if you want
    $cluster = New-Cluster -Name $Name -Location $Datacenter -HAEnabled:$false -DRSEnabled:$false
    Write-Host "Created Cluster: $Name"
    return $cluster
}

function Ensure-HostInVCenter {
    param(
        [string]$HostName,
        [object]$Location,
        [pscredential]$HostCred
    )

    $existing = Get-VMHost -Name $HostName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Host already present: $HostName"
        return $existing
    }

    if ($script:WhatIf) {
        Write-Host "WhatIf: would add host '$HostName' to '$($Location.Name)'"
        return $null
    }

    Write-Host "Adding host: $HostName"
    return Add-VMHost -Name $HostName -Location $Location -Credential $HostCred -Force
}

function Get-VMXFilesOnDatastore {
    param([VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.DatastoreImpl]$Datastore)

    # Use a VimDatastore PSDrive so we can recurse with Get-ChildItem
    $driveName = "ds"
    if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name $driveName -Force
    }

    New-PSDrive -Name $driveName -PSProvider VimDatastore -Root "\" -Datastore $Datastore | Out-Null
    Get-ChildItem -Path ($driveName + ":\") -Recurse -Include *.vmx -ErrorAction SilentlyContinue
}

function Register-VMsFromHostDatastores {
    param(
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$VMHost,
        [string[]]$DatastoreAllowList
    )

    Write-Host ""
    Write-Host "=== Scanning host: $($VMHost.Name) ==="

    # Map of already-registered VMX paths on this host to avoid duplicates
    $registered = @{}
    Get-VM -VMHost $VMHost -ErrorAction SilentlyContinue | ForEach-Object {
        $p = $_.ExtensionData.Config.Files.VmPathName
        if ($p) { $registered[$p.ToLowerInvariant()] = $true }
    }

    $datastores = Get-Datastore -VMHost $VMHost |
        Where-Object { $_.ExtensionData.Summary.Accessible -eq $true } |
        Sort-Object Name

    if ($DatastoreAllowList -and $DatastoreAllowList.Count -gt 0) {
        $datastores = $datastores | Where-Object { $DatastoreAllowList -contains $_.Name }
    }

    foreach ($ds in $datastores) {
        Write-Host "Datastore: $($ds.Name)"
        $vmxFiles = Get-VMXFilesOnDatastore -Datastore $ds

        foreach ($f in $vmxFiles) {
            # Convert "ds:\folder\vm.vmx" to "[datastore] folder/vm.vmx"
            $relative = $f.FullName -replace "^[a-zA-Z]+:\\", ""
            $relative = $relative -replace "\\", "/"
            $vmxPath  = "[{0}] {1}" -f $ds.Name, $relative

            if ($registered.ContainsKey($vmxPath.ToLowerInvariant())) {
                Write-Host "  SKIP (already registered): $vmxPath"
                continue
            }

            if ($script:WhatIf) {
                Write-Host "  WhatIf: would REGISTER: $vmxPath"
                continue
            }

            try {
                Write-Host "  REGISTER: $vmxPath"
                $vm = Register-VM -Path $vmxPath -VMHost $VMHost -ErrorAction Stop
                Write-Host "    OK: $($vm.Name)"
            } catch {
                Write-Warning "    FAILED: $vmxPath :: $($_.Exception.Message)"
            }
        }
    }
}

# -----------------------------
# Main
# -----------------------------
try {
    Ensure-NuGetProvider
    Ensure-PowerCLI

    $vCenterCred = New-PlainCredential -User $vCenterUser -Password $vCenterPassword
    $esxiCred    = New-PlainCredential -User $esxiUser    -Password $esxiPassword

    Write-Host "Connecting to vCenter: $vCenter"
    Connect-VIServer -Server $vCenter -Credential $vCenterCred | Out-Null

    $dc = Ensure-Datacenter -Name $DatacenterName
    if (-not $dc -and -not $WhatIf) { throw "Failed to create/find Datacenter '$DatacenterName'." }

    $cluster = $null
    if ($dc) {
        $cluster = Ensure-Cluster -Name $ClusterName -Datacenter $dc
    }

    # Location to add hosts: cluster if present, else datacenter
    $location = if ($cluster) { $cluster } else { $dc }

    foreach ($h in $Hosts) {
        $vmhost = Ensure-HostInVCenter -HostName $h -Location $location -HostCred $esxiCred
        if ($vmhost) {
            Register-VMsFromHostDatastores -VMHost $vmhost -DatastoreAllowList $OnlyDatastores
        }
    }

} finally {
    try {
        Disconnect-VIServer -Server $vCenter -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    } catch {}
    Write-Host ""
    Write-Host "Done."
}
