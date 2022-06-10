### usage: ./snapshotList.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] [ -olderThan 30 ] [ -sorted ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$olderThan = 0,
    [Parameter()][switch]$sorted
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$report = @{}
$sortableList = @()

$objects = api get /snmp/config


