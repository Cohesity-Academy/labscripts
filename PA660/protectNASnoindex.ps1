# usage: ./protectPhysicalLinux.ps1 -vip mycluster -username myusername -jobName 'My Job' -serverList ./servers.txt -exclusionList ./exclusions.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password = '',  # local or AD domain password
    [Parameter()][string]$jobName = '',  # name of protection job
    [Parameter()][array]$nas = '',  # optional name of one nas source
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',
    [Parameter()][string]$policyName = ''
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
Import-Module $(Join-Path -Path $PSScriptRoot -ChildPath userRights.psm1)

### authenticate
apiauth -vip $vip -username $username -password $password -domain $domain


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
    "name" = "$jobName";
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
