# ================================
# PowerShell 5.1 Compatibility
# ================================
#svc_cohesity VMware123!
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install NuGet if missing
if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

# Install PowerCLI if not present
if (!(Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    Install-Module VMware.PowerCLI -Scope CurrentUser -Force -AllowClobber
}

Import-Module VMware.PowerCLI

# Ignore invalid certificates
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

# ================================
# vCenter Connection Info
# ================================
$vCenterServer = "vcenter.acme.com"
$vcUser = "administrator@acme.com"
$vcPass = "Cohesity123!"
$CohesityUser = 'ACME.COM\svc_cohesity'

Connect-VIServer $vCenterServer -User $vcUser -Password $vcPass

$roleName = "Cohesity_DataProtect_Role"

# ================================
# COMPLETE COHESITY PRIVILEGE SET
# ================================

$privilegeIds = @(

# ---- Cryptographic Operations ----
"Cryptographer.Access",
"Cryptographer.AddDisk",
"Cryptographer.DirectAccess",
"Cryptographer.EncryptNew",
"Cryptographer.Migrate",
"Cryptographer.ManageKeyServers",

# ---- Datastore ----
"Datastore.AllocateSpace",
"Datastore.Browse",
"Datastore.Config",
"Datastore.FileManagement",
"Datastore.Move",
"Datastore.DeleteFile",
"Datastore.ConfigureIOManagement",

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

# ---- Host ----
"Host.Config.Maintenance",
"Host.Config.Patch",
"Host.Config.Storage",

# ---- Network ----
"Network.Assign",

# ---- Resource ----
"Resource.AssignVMToPool",
"Resource.ColdMigrate",
"Resource.HotMigrate",

# ---- Sessions ----
"Sessions.TerminateSession",

# ---- Virtual Machine: Configuration ----
"VirtualMachine.Config.DiskLease",
"VirtualMachine.Config.AddExistingDisk",
"VirtualMachine.Config.AddNewDisk",
"VirtualMachine.Config.RemoveDisk",
"VirtualMachine.Config.AddRemoveDevice",
"VirtualMachine.Config.EditDevice",
"VirtualMachine.Config.DeviceConnection",
"VirtualMachine.Config.AdvancedConfig",
"VirtualMachine.Config.Settings",
"VirtualMachine.Config.RawDevice",
"VirtualMachine.Config.SwapPlacement",
"VirtualMachine.Config.Rename",
"VirtualMachine.Config.MksControl",
"VirtualMachine.Config.Annotation",
"VirtualMachine.Config.ChangeTracking",
"VirtualMachine.Config.UpgradeVirtualHardware",
"VirtualMachine.Config.CPUCount",
"VirtualMachine.Config.Memory",
"VirtualMachine.Config.Resource",

# ---- Virtual Machine: Inventory ----
"VirtualMachine.Inventory.Create",
"VirtualMachine.Inventory.Register",
"VirtualMachine.Inventory.Delete",
"VirtualMachine.Inventory.Unregister",

# ---- Virtual Machine: Guest Operations ----
"VirtualMachine.GuestOperations.Modify",
"VirtualMachine.GuestOperations.Execute",
"VirtualMachine.GuestOperations.Query",

# ---- Virtual Machine: Interaction ----
"VirtualMachine.Interact.DeviceConnection",
"VirtualMachine.Interact.GuestControl",
"VirtualMachine.Interact.PowerOff",
"VirtualMachine.Interact.PowerOn",

# ---- Virtual Machine: Provisioning ----
"VirtualMachine.Provisioning.DiskRandomAccess",
"VirtualMachine.Provisioning.DiskRandomRead",
"VirtualMachine.Provisioning.GetVmFiles",
"VirtualMachine.Provisioning.Customize",
"VirtualMachine.Provisioning.MarkAsTemplate",

# ---- Virtual Machine: Snapshot ----
"VirtualMachine.State.CreateSnapshot",
"VirtualMachine.State.RemoveSnapshot",
"VirtualMachine.State.RevertToSnapshot",

# ---- vApp ----
"VApp.AssignVM",
"VApp.AssignResourcePool",
"VApp.Unregister",

# ---- vSphere Tagging ----
"InventoryService.Tagging.AttachTag",
"InventoryService.Tagging.AttachTagOnObject",
"InventoryService.Tagging.CreateTag",
"InventoryService.Tagging.CreateCategory",
"InventoryService.Tagging.DeleteTag",
"InventoryService.Tagging.DeleteCategory",
"InventoryService.Tagging.EditTag",
"InventoryService.Tagging.EditCategory",

# ---- VM Storage Policies ----
"StorageProfile.Update",
"StorageProfile.View",
"StorageProfile.Apply"
)

# ================================
# Validate Privileges Exist
# ================================

$availablePrivileges = Get-VIPrivilege
$validPrivileges = $availablePrivileges | Where-Object { $privilegeIds -contains $_.Id }

Write-Host "Validated $($validPrivileges.Count) privileges available in this vCenter."

if ($validPrivileges.Count -eq 0) {
    Write-Host "No matching privileges found. Check vSphere version."
    Disconnect-VIServer -Confirm:$false
    return
}

# ================================
# Create or Update Role
# ================================

$existingRole = Get-VIRole -Name $roleName -ErrorAction SilentlyContinue

if (-not $existingRole) {
    New-VIRole -Name $roleName -Privilege $validPrivileges
    Write-Host "Role created successfully."
}
else {
    Set-VIRole -Role $existingRole -AddPrivilege $validPrivileges
    Write-Host "Role updated successfully."
}

# ================================
# Assign Permission at Root
# ================================

$rootFolder = Get-Folder -Name "Datacenters"
$existingPermission = Get-VIPermission -Entity $rootFolder -Principal $CohesityUser -ErrorAction SilentlyContinue

if (-not $existingPermission) {
    New-VIPermission -Entity $rootFolder -Principal $CohesityUser -Role $roleName -Propagate:$true
    Write-Host "Permission assigned to $CohesityUser."
}
else {
    Write-Host "Permission already exists for $CohesityUser."
}

# List all Roles
# Get-VIPrivilege | Sort-Object Id | Format-Table Id, Name -Auto

Disconnect-VIServer -Confirm:$false

Write-Host "Cohesity role configuration complete."
