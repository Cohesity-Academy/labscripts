### usage: ./snapshotList.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] [ -olderThan 30 ] [ -sorted ]

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

If ($objects.readUser.userName -eq "cohesityV2Public") {
    Set-ActivityResult -Correct
}
Else {Set-ActivityResult -Incorrect}
#$objects.server = 192.168.1.90
#$objects.trapUser.userName = cohesityV2Public
#$objects.version = kSnmpV2
$objects.readUser.userName #cohesityV2Public

