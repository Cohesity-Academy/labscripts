### usage: ./validation.ps1 -vip mycluster -username myusername -passsword 

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter(Mandatory = $True)][string]$password
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -password $password -quiet

$objects = api get -v2 data-protect/protection-groups

$pgs = ($objects.protectionGroups | Where-Object name -eq "VirtualProtection")

if ($pgs.hypervParams.objects.name -contains "Guest-VM-2") {
    Write-Host "Correct"
} else {
    Write-Host "Incorrect"
}
