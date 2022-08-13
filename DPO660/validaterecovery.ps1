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

$objects = api get -v2 data-protect/recoveries

If ((($objects |?{$_.recoveries.physicalParams.objects.objectInfo.name -eq "cohesity-jump.cohesitylabs.az"}).recoveries.physicalParams.recoverFileAndFolderParams.filesAndFolders.absolutePath) -eq  "/C/Users/Coh-Student.COHESITYLABS/Documents/Cohesity/Images/cohesity.png"){
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}

