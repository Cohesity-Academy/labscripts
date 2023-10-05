$myObject = @{
    "name" = "S3CloudStorage";
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
                                                "bucketName" = "S3CloudStorage";
                                                "accessKeyId" = "nYSpV_nv1-hg0Wbm4rwy3Pvtda-1iQiUbsh24Sr
m86o";
                                                "secretAccessKey" = "1yVcchHXVCgGqP3na-b9onbrFxxQBcQf9jP
j917G1P0";
                                                "endPoint" = "cohesity-b.cohesitylabs.az:3000";
                                                "secureConnection" = $true;
                                                "signatureVersion" = 2;
                                                "isAwsSnowball" = $false;
                                                "isForeverIncrementalArchivalEnabled" = $true;
                                                "isIncrementalArchivalEnabled" = $false;
                                                "sourceSideDeduplication" = $true
                                            }
                       }
}
