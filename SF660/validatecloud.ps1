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

$pol = api get -v2 data-protect/policies

If (($pol |?{$_.policies.name -eq "silver"}).policies.remotetargetPolicy.archivalTargets.targetName -eq  "Az-Cool-Blob-Archive"){
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
