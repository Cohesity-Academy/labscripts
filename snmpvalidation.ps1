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

$objects = api get /snmp/config

If ($objects.server -eq "192.168.1.90" -and
    $objects.trapUser.userName -eq "cohesityV2Public" -and
    $objects.version -eq "kSnmpV2" -and
    $objects.readUser.userName -eq "cohesityV2Public") {
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
