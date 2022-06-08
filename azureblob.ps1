[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
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
    "_encryptionEdited" = $true
}
$null = api post vaults $myObject
