### usage: ./logvalidation.ps1 -vip mycluster -username myusername -passsword 

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

$poldatalockobjects = api get -v2 data-protect\policies

If (($poldatalockobjects.policies |?{$_.name -eq "Gold"}).extendedRetention.retention.dataLockConfig.mode -eq "Compliance") {
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
