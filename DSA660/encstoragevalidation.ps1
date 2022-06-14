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

$encstorobjects = api get users

If (($encstorobjects |?{$_.name -eq "sd-idd-ic-encrypt"}).storagePolicy.encryptPolicy -eq "kEncryptionStrong") {
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
