# ================================
# PowerShell 5.1 + PowerCLI setup
# ================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

if (!(Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    Install-Module VMware.PowerCLI -Scope CurrentUser -Force -AllowClobber
}

Import-Module VMware.PowerCLI
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

# ================================
# ESXi Connection Info
# ================================
$esxiHost  = "esxi01.acme.com"
$esxiUser  = "root"
$esxiPass  = "YourRootPassword!"

# Principal to assign permissions to:
# - local ESXi user example: "svc_cohesity"
# - if ESXi is joined to AD: "ACME\svc_cohesity"
$principal = "svc_cohesity"

$roleName = "Cohesity_DataProtect_Role"

Connect-VIServer -Server $esxiHost -User $esxiUser -Password $esxiPass

# ================================
# Requested Privileges (IDs)
# ================================
$privilegeIds = @(
    # ---- Datastore ----
    "Datastore.AllocateSpace",
    "Datastore.Browse",
    "Datastore.Config",
    "Datastore.Delete", # may not exist on all builds
    "Datastore.DeleteFile",
    "Datastore.FileManagement",
    "Datastore.Move",
    "Datastore.Rename",
    "Datastore.UpdateVirtualMachineFiles",
    "Datastore.UpdateVirtualMachineMetadata",

    # ---- Folder ----
    "Folder.Create",
    "Folder.Delete",

    # ---- Global ----
    "Global.DisableMethods",
    "Global.EnableMethods",
    "Global.Licenses",
    "Global.LogEvent",
    "Global.ManageCustomFields",
    "Global.SetCustomField",

    # ---- Host - Configuration ----
    "Host.Config.Storage",

    # ---- Host - Local operations ----
    "Host.Local.DeleteVM",  # if missing, see notes below

    # ---- Network ----
    "Network.Assign",

    # ---- Resource ----
    "Resource.AssignVMToPool",
    "Resource.ColdMigrate",
    "Resource.HotMigrate",

    # ---- System ----
    "System.Anonymous",
    "System.Read",
    "System.View",

    # ---- vApp ----
    "VApp.AssignResourcePool",
    "VApp.AssignVM",
    "VApp.Unregister",

    # ---- Sessions ----
    "Sessions.TerminateSession",

    # ---- Virtual Machine - Configuration ----
    "VirtualMachine.Config.AddExistingDisk",
    "VirtualMachine.Config.AddNewDisk",
    "VirtualMachine.Config.AddRemoveDevice",
    "VirtualMachine.Config.AdvancedConfig",
    "VirtualMachine.Config.Annotation",
    "VirtualMachine.Config.CPUCount",
    "VirtualMachine.Config.ChangeTracking",
    "VirtualMachine.Config.AcquireDiskLease",  # "DiskLease" in UI
    "VirtualMachine.Config.EditDevice",
    "VirtualMachine.Config.HostUSBDevice",
    "VirtualMachine.Config.Memory",
    "VirtualMachine.Config.RawDevice",
    "VirtualMachine.Config.ReloadFromPath",
    "VirtualMachine.Config.RemoveDisk",
    "VirtualMachine.Config.Rename",
    "VirtualMachine.Config.ResetGuestInfo",
    "VirtualMachine.Config.Resource",
    "VirtualMachine.Config.Settings",
    "VirtualMachine.Config.SwapPlacement",
    "VirtualMachine.Config.UpgradeVirtualHardware", # "Upgrade compatibility" in UI

    # ---- Virtual Machine - GuestOperations ----
    "VirtualMachine.GuestOperations.Execute",
    "VirtualMachine.GuestOperations.Modify",
    "VirtualMachine.GuestOperations.Query",

    # ---- Virtual Machine - Interact ----
    "VirtualMachine.Interact.GuestControl",
    "VirtualMachine.Interact.PowerOff",
    "VirtualMachine.Interact.PowerOn",

    # ---- Virtual Machine - Inventory ----
    "VirtualMachine.Inventory.Create",
    "VirtualMachine.Inventory.Delete",
    "VirtualMachine.Inventory.Register",
    "VirtualMachine.Inventory.Unregister",

    # ---- Virtual Machine - Provisioning ----
    "VirtualMachine.Provisioning.DiskRandomRead",
    "VirtualMachine.Provisioning.GetVmFiles",

    # ---- Virtual Machine - State (Snapshots) ----
    "VirtualMachine.State.CreateSnapshot",
    "VirtualMachine.State.RemoveSnapshot",
    "VirtualMachine.State.RevertToSnapshot",

    # ---- Cryptographic Operations ----
    "Cryptographer.AddDisk",
    "Cryptographer.Access",
    "Cryptographer.EncryptNew", # some builds use EncryptNew instead of Encrypt
    "Cryptographer.Migrate"
)

# ================================
# Validate privileges exist
# ================================
$available = Get-VIPrivilege

$valid = $available | Where-Object { $privilegeIds -contains $_.Id }
$missing = $privilegeIds | Where-Object { $_ -notin $available.Id }

Write-Host "Validated $($valid.Count) privilege IDs on this ESXi host."
if ($missing.Count -gt 0) {
    Write-Warning "Missing privilege IDs on this host (won't be added):"
    $missing | Sort-Object | ForEach-Object { Write-Host "  - $_" }
}

if ($valid.Count -eq 0) {
    Write-Error "No matching privileges found. Check ESXi version / PowerCLI connection."
    Disconnect-VIServer -Confirm:$false
    return
}

# ================================
# Create or update role
# ================================
$existingRole = Get-VIRole -Name $roleName -ErrorAction SilentlyContinue

if (-not $existingRole) {
    New-VIRole -Name $roleName -Privilege $valid | Out-Null
    Write-Host "Role created: $roleName"
} else {
    # Set-VIRole replaces privileges; AddPrivilege only appends.
    # Since you want an exact set, do replace.
    Set-VIRole -Role $existingRole -Privilege $valid | Out-Null
    Write-Host "Role updated (replaced privileges): $roleName"
}

# ================================
# Assign permission on the ESXi host (propagate)
# ================================
$vmhostObj = Get-VMHost -Name $esxiHost -ErrorAction Stop

$existingPerm = Get-VIPermission -Entity $vmhostObj -Principal $principal -ErrorAction SilentlyContinue
if (-not $existingPerm) {
    New-VIPermission -Entity $vmhostObj -Principal $principal -Role $roleName -Propagate:$true | Out-Null
    Write-Host "Permission assigned: $principal -> $roleName on $esxiHost (Propagate=TRUE)"
} else {
    Write-Host "Permission already exists for $principal on $esxiHost"
}

# List all roles
# Get-VIPrivilege | Sort-Object Id | Format-Table Id, Name -Auto

Disconnect-VIServer -Confirm:$false
Write-Host "Standalone ESXi role configuration complete."