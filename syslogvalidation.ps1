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

$objectssyslogs = api get -v2 syslogs

If ($objectssyslogs.syslogServers.ip -eq "192.168.1.90" -and
    $objectssyslogs.syslogServers.protocol -eq "udp" -and
    $objectssyslogs.syslogServers.programNameList -eq "dataprotection_events") {
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
