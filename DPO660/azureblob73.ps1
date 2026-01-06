#$scriptName = 'azureblob'
#$repoURL = 'https://raw.githubusercontent.com/cohesity-academy/labscripts/main/DSA660'
#(Invoke-WebRequest -Uri "$repoUrl/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
#(Invoke-WebRequest -Uri "$repoUrl/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
#./azureblob.ps1 -vip cluster -username user -password password -Name "CoolBlob" -tierType "AzureCoolBlob" -StorageAccountName "cool####" -StorageAccessKey "thekey" -bucketName "cohesitystorage" -fucntionName "Name" -functionKey "key"


[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,
    [Parameter(Mandatory = $True)][string]$tierType, #kAzureTierCool, kAzureTierHot, kAzureTierArchive
    [Parameter(Mandatory = $True)][string]$name, #Name of Blob
    [Parameter(Mandatory = $True)][string]$storageAccountName, #Storage Container Name
    [Parameter(Mandatory = $True)][string]$storageAccessKey, #Storage Access Key
    [Parameter(Mandatory = $True)][string]$bucketName, #Storage Container name
    [Parameter(Mandatory = $True)][string]$functionName, #Storage Container Name
    [Parameter(Mandatory = $True)][string]$functionKey #Storage Access Key
    
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

$myObject = @{
    "name" = "$name";
    "purposeType" = "Archival";
    "compression" = "Low";
    "enableObjectLock" = $false;
    "archivalParams" = @{
                           "storageType" = "Azure";
                           "encryption" = @{
                                              "encryptionLevel" = "Strong";
                                              "kmsServerId" = 0;
                                              "enableAdditionalSecurity" = $false
                                          };
                           "azureParams" = @{
                                               "storageClass" = "$tierType";
                                               "containerName" = "$bucketName";
                                               "storageAccountName" = "$storageAccountName";
                                               "storageAccessKey" = "$storageAccessKey";
                                               "coolBlobParams" = @{
                                                                      "category" = "AzureStandard";
                                                                      "functionAppName" = "$functionName";
                                                                      "functionAppDeploymentKey" = "$functionKey"
                                                                  };
                                               "isForeverIncrementalArchivalEnabled" = $true;
                                               "isIncrementalArchivalEnabled" = $false;
                                               "sourceSideDeduplication" = $true
                                           }
                       }
}

$null = api post vaults $myObject
