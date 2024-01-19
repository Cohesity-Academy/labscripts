# usage: ./protectPhysicalLinux.ps1 -vip mycluster -username myusername -jobName 'My Job' -serverList ./servers.txt -exclusionList ./exclusions.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password = '',  # local or AD domain password
    [Parameter()][string]$domain = 'local',  # local or AD domain username
    [Parameter()][array]$servers = '',  # optional name of one server protect
    [Parameter()][string]$serverList = '',  # optional textfile of servers to protect
    [Parameter()][array]$inclusions = '', # optional paths to exclude (comma separated)
    [Parameter()][string]$inclusionList = '',  # optional list of exclusions in file
    [Parameter()][array]$exclusions = '',  # optional name of one server protect
    [Parameter()][string]$exclusionList = '',  # required list of exclusions
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add server to
    [Parameter()][switch]$skipNestedMountPoints,  # 6.3 and below - skip all nested mount points
    [Parameter()][array]$skipNestedMountPointTypes = @(),  # 6.4 and above - skip listed mount point types
    [Parameter()][switch]$replaceRules,
    [Parameter()][switch]$allServers,
    [Parameter()][string]$metadataFile = '',
    [Parameter()][string]$startTime = '20:00',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][int]$fullSlaMinutes = 120,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',
    [Parameter()][string]$policyName,
    [Parameter()][ValidateSet('kBackupHDD', 'kBackupSSD')][string]$qosPolicy = 'kBackupHDD'
)

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
