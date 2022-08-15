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

$jobs = api get protectionJobs

$id = ($jobs |?{$_.name -eq "HyperVReplicationProtection"}).id
$objects= api get protectionRuns?jobId=$id
If (($objects |?{$_.backupRun.sourceBackupStatus.source.name -eq "copy-Guest-VM-1"}){
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
