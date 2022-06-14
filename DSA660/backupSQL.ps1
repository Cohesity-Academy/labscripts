$myObject = @{
    "policyId" = "8158516650510261:1575649096260:1";
    "startTime" = @{
                      "hour" = 20;
                      "minute" = 23;
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
    "name" = "SQLProtection";
    "environment" = "kSQL";
    "isPaused" = $false;
    "description" = "";
    "alertPolicy" = @{
                        "backupRunStatus" = @(
                                                "kFailure"
                                            );
                        "alertTargets" = @(

                                         )
                    };
    "mssqlParams" = @{
                        "protectionType" = "kFile";
                        "fileProtectionTypeParams" = @{
                                                         "performSourceSideDeduplication" = $false;
                                                         "fullBackupsCopyOnly" = $false;
                                                         "userDbBackupPreferenceType" = "kBackupAllDatabases";
                                                         "backupSystemDbs" = $true;
                                                         "useAagPreferencesFromServer" = $true;
                                                         "objects" = @(
                                                                         @{
                                                                             "id" = 18
                                                                         };
                                                                         @{
                                                                             "id" = 19
                                                                         };
                                                                         @{
                                                                             "id" = 20
                                                                         };
                                                                         @{
                                                                             "id" = 17
                                                                         }
                                                                     )
                                                     }
                    }
}
