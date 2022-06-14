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

$mfaobjects = api get -v2 mfa-config

If ($mfaobjects.authenticationTypes -eq "Email" -and
    $mfaobjects.enabled -eq "True") {
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
