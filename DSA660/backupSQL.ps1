# usage: ./backupolicy.ps1 -vip mycluster -username myusername -password mypassword -Name "policyname" -frequency frequencyinminutes

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password
    [Parameter(Mandatory = $True)][int]$frequency,  # backup in min   
    [Parameter(Mandatory = $True)][string]$name  # name of policy
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

$jobs = api get protectionSources/ProtectedObjects

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
                                                                             "id" = $job.id[0]
                                                                         };
                                                                         @{
                                                                             "id" = $job.id[1]
                                                                         };
                                                                         @{
                                                                             "id" = $job.id[2]
                                                                         };
                                                                         @{
                                                                             "id" = $job.id[3]
                                                                         }
                                                                     )
                                                     }
                    }
}
$newsqlbackup = api post -v2 data-protect/policies $myObject
