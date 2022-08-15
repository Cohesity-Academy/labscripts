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

$objects = api get protectionRuns
$expire = ($objects |?{$_.jobname -eq "NasProtection"}).copyRun[0].expiryTimeUsecs
$start = ($objects |?{$_.jobname -eq "NasProtection"}).copyRun[0].runStartTimeUsecs

$timeinuseconds = $expire - $start

If ( $timeinuseconds -gt 15550000000000){
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}