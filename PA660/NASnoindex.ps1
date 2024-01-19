

$myObject = @{
    "policyId" = "8158516650510261:1575649096260:3";
    "startTime" = @{
                      "hour" = 15;
                      "minute" = 39;
                      "timeZone" = "America/New_York"
                  };
    "priority" = "kMedium";
    "sla" = @(
                @{
                    "backupRunType" = "kFull";
                    "slaMinutes" = 120
                };
                @{
                    "backupRunType" = "kIncremental";
                    "slaMinutes" = 60
                }
            );
    "qosPolicy" = "kBackupHDD";
    "abortInBlackouts" = $false;
    "storageDomainId" = 3203;
    "name" = "SMB-NAS";
    "environment" = "kGenericNas";
    "isPaused" = $false;
    "description" = "";
    "alertPolicy" = @{
                        "backupRunStatus" = @(
                                                "kFailure"
                                            );
                        "alertTargets" = @(

                                         )
                    };
    "genericNasParams" = @{
                             "objects" = @(
                                             @{
                                                 "id" = 50
                                             }
                                         );
                             "indexingPolicy" = @{
                                                    "enableIndexing" = $false;
                                                    "includePaths" = @(

                                                                     );
                                                    "excludePaths" = @(

                                                                     )
                                                };
                             "protocol" = "kNfs3";
                             "continueOnError" = $true;
                             "fileFilters" = @{
                                                 "includeList" = @(
                                                                     "/"
                                                                 );
                                                 "excludeList" = @(
                                                                     "/.snapshot/"
                                                                 )
                                             };
                             "encryptionEnabled" = $false;
                             "excludeObjectIds" = @(

                                                  )
                         }
}
