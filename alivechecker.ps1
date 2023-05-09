#$scriptName = 'alivechecker'
#$repoURL = 'https://raw.githubusercontent.com/cohesity-academy/labscripts/main/'
#(Invoke-WebRequest -Uri "$repoUrl/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
#(Invoke-WebRequest -Uri "$repoUrl/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
#./alivechecker.ps1 -vip clusteripname -username user -password password

[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter(Mandatory = $True)][string]$password   
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### Cohesity status checker
$synced = $false
while($synced -eq $false){
    Start-Sleep -Seconds 10
    apiauth -vip $vip -username $username -password $password -quiet
    if($AUTHORIZED -eq $true){
        $stat = api get /nexus/cluster/status
        if($stat.isServiceStateSynced -eq $true){
            $synced = $true
        }
    }    
}
write-host "Cluster $vip is READY!!!"
