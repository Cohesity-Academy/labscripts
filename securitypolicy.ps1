# usage: ./securitypolicy.ps1 -vip mycluster -username myusername -password mypassword 

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

$secpol = @{
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

$newpol = api post -v2 security-config $secpol
