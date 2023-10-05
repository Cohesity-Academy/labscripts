

Connect-CohesityCluster -Server cohesity-b.cohesitylabs.az -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "local\admin", (ConvertTo-SecureString -AsPlainText "cohesity123" -Force))
$admininfo = Get-CohesityUser -Names admin
$vip = "Cohesity-a.cohesitylabs.az"
$username = "admin"
$password = "cohesity123"
$s3endpoint = "cohesity-b.cohesitylabs.az:3000"
$name = "S3CloudStorage"
$bucketName = "S3CloudStorage"
$accessKeyId = $admininfo.S3AccessKeyId
$secretAccessKey = $admininfo.S3SecretKey

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
