$myObject = @{
    "passwordStrength" = @{
                             "minLength" = 8;
                             "includeUpperLetter" = $false;
                             "includeLowerLetter" = $false;
                             "includeNumber" = $false;
                             "includeSpecialChar" = $false
                         };
    "passwordReuse" = @{
                          "numDisallowedOldPasswords" = 0;
                          "numDifferentChars" = 0
                      };
    "passwordLifetime" = @{
                             "minLifetimeDays" = 0;
                             "maxLifetimeDays" = 1800000
                         };
    "accountLockout" = @{
                           "maxFailedLoginAttempts" = 3;
                           "failedLoginLockTimeDurationMins" = 15;
                           "inactivityTimeDays" = 35
                       };
    "dataClassification" = @{
                               "isDataClassified" = $false;
                               "classifiedDataMessage" = "";
                               "unclassifiedDataMessage" = ""
                           };
    "sessionConfiguration" = @{
                                 "absoluteTimeout" = 86400;
                                 "inactivityTimeout" = 3600;
                                 "limitSessions" = $false;
                                 "sessionLimitPerUser" = 10;
                                 "sessionLimitSystemWide" = 100000
                             };
    "certificateBasedAuth" = @{
                                 "enableMappingBasedAuthentication" = $false;
                                 "certificateMapping" = "CommonName";
                                 "adMapping" = "SamAccountName"
                             }
}
