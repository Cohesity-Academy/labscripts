#$scriptName = 'azureblob'
#$repoURL = 'https://raw.githubusercontent.com/cohesity-academy/labscripts/main'
#(Invoke-WebRequest -Uri "$repoUrl/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
#(Invoke-WebRequest -Uri "$repoUrl/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
#./azureblob.ps1 -vip cohesity-a.cohesitylabs.az -username user -password password -Name "CoolBlob" -tierType "kAzureTierCool" -StorageAccountName "cool####" -StorageAccessKey "thekey" -bucketName "cohesitystorage"

[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,
    [Parameter(Mandatory = $True)][string]$tierType, #kAzureTierCool, kAzureTierHot, kAzureTierArchive
    [Parameter(Mandatory = $True)][string]$name, #Name of Blob
    [Parameter(Mandatory = $True)][string]$storageAccountName, #Storage Container Name
    [Parameter(Mandatory = $True)][string]$storageAccessKey, #Storage Access Key
    [Parameter(Mandatory = $True)][string]$bucketName #Storage Container name
    
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

    $myObject = @{
    "compressionPolicy" = "kCompressionLow";
    "config" = @{
                   "azure" = @{
                                 "tierType" = "$tierType";
                                 "storageAccountName" = "$storageAccountName";
                                 "storageAccessKey" = "$storageAccessKey"
                             };
                   "bucketName" = "$bucketName"
               };
    "dedupEnabled" = $true;
    "encryptionPolicy" = "kEncryptionNone";
    "incrementalArchivesEnabled" = $true;
    "kmsServerId" = 0;
    "name" = "$name";
    "usageType" = "kArchival";
    "kmsServiceType" = "kInternalKMS";
    "_tierData" = @{
                      "tier" = "kAzureTierCool";
                      "vault" = "kAzure";
                      "govVault" = "kAzureGovCloud";
                      "targetType" = "kAzure"
                  };
    "archivalFormat" = "incremental";
    "isAwsSnowball" = $false;
    "isForeverIncrementalArchiveEnabled" = $false;
    "externalTargetType" = "kAzure";
    "_title" = "standard";
    "_encryptionEdited" = $true;
}
$null = api post vaults $myObject
