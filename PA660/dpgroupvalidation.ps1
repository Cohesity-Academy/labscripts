### usage: ./dpgroupvalidation.ps1 -vip mycluster -username myusername -password 

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

$objectsdpgroups = api get -v2 data-protect/protection-groups

If ($objectsdpgroups.protectionGroups[0].name -eq "Ransomware" -and
    $objectsdpgroups.protectionGroups[1].name -eq "NasProtection" -and
    $objectsdpgroups.protectionGroups[2].name -eq "SQLProtection") {
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
