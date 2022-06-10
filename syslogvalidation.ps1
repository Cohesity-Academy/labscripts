### usage: ./snmpvalidation.ps1 -vip mycluster -username myusername -passsword 

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

$objectssyslogs = api -v2 get syslogs

If ($objectssyslogs.server -eq "192.168.1.90" -and
    $objectssyslogs.trapUser.userName -eq "cohesityV2Public" -and
    $objectssyslogs.version -eq "kSnmpV2" -and
    $objectssyslogs.readUser.userName -eq "cohesityV2Public") {
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
