

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)][string]$vip = "cohesity-a.cohesitylabs.az",  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $false)][string]$username = "admin",  # username (local or AD)
    [Parameter(Mandatory = $false)][string]$password = "cohesity123",  # local or AD domain password
    [Parameter(Mandatory = $false)][string]$name = "S3CloudStorage",  # name of protectiongroup
    [Parameter(Mandatory = $false)][string]$bucketname = "S3CloudStorage", # name of policy
    [Parameter(Mandatory = $false)][string]$vipremote = "cohesity-b.cohesitylabs.az",  # name of source
    [Parameter(Mandatory = $false)][string]$userremote = "admin",  # name of protectiongroup
    [Parameter(Mandatory = $false)][string]$passremote = "cohesity123" # name of policy
)


Connect-CohesityCluster -Server $vipremote -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "local\$userremote", (ConvertTo-SecureString -AsPlainText "$passremote" -Force))
$admininfo = Get-CohesityUser -Names admin
$s3endpoint = "$vipremote:3000"
#$name = "S3CloudStorage"
#$bucketName = "S3CloudStorage"
$accessKeyId = $admininfo.S3AccessKeyId
$secretAccessKey = $admininfo.S3SecretKey

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

apiauth -vip $vip -username $username -password $password -domain $domain

$myObject = @{
    "name" = "$name";
    "purposeType" = "Archival";
    "compression" = "Low";
    "archivalParams" = @{
                           "storageType" = "S3Compatible";
                           "encryption" = @{
                                              "encryptionLevel" = "Strong";
                                              "kmsServerId" = 0;
                                              "enableAdditionalSecurity" = $false
                                          };
                           "s3CompParams" = @{
                                                "bucketName" = "$bucketName";
                                                "accessKeyId" = "$accessKeyId";
                                                "secretAccessKey" = "$secretAccessKey";
                                                "endPoint" = "$s3endpoint";
                                                "secureConnection" = $true;
                                                "signatureVersion" = 2;
                                                "isAwsSnowball" = $false;
                                                "isForeverIncrementalArchivalEnabled" = $true;
                                                "isIncrementalArchivalEnabled" = $false;
                                                "sourceSideDeduplication" = $true
                                            }
                       }
}

api post -v2 data-protect/external-targets $myObject
