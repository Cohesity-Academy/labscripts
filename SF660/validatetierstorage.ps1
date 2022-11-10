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

$storage = api get viewBoxes
$vault = api get vaults

If ($storage |?{$_.name -eq "sd-idd-ic-Tier"} -and ($vault |?{$_.name -eq "Az-Hot-Blob-Tier"} ) {
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
