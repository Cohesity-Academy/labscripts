# usage: ./hypervprotection.ps1 -vip clusername -username admin -password password -Name ""

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password
    [Parameter(Mandatory = $True)][string]$name  # name of policy
    )

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

$myObject = @{
    "policyId" = "206091916102903:1764101577797:16";
    "startTime" = @{
                      "hour" = 11;
                      "minute" = 48;
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
    "storageDomainId" = 3487;
    "name" = "$name";
    "environment" = "kHyperV";
    "isPaused" = $false;
    "pausedNote" = "";
    "description" = "";
    "alertPolicy" = @{
                        "backupRunStatus" = @(
                                                "kFailure";
                                                "kSlaViolation"
                                            );
                        "alertTargets" = @(

                                         )
                    };
    "hypervParams" = @{
                         "objects" = @(
                                         @{
                                             "id" = 17;
                                             "isAutoprotected" = $false
                                         };
                                         @{
                                             "id" = 18;
                                             "isAutoprotected" = $false
                                         }
                                     );
                         "excludeObjectIds" = @(

                                              );
                         "vmTagIds" = @(

                                      );
                         "excludeVmTagIds" = @(

                                             );
                         "protectionType" = "kAuto";
                         "appConsistentSnapshot" = $false;
                         "fallbackToCrashConsistentSnapshot" = $true;
                         "indexingPolicy" = @{
                                                "enableIndexing" = $true;
                                                "includePaths" = @(
                                                                     "/"
                                                                 );
                                                "excludePaths" = @(
                                                                     "/$Recycle.Bin";
                                                                     "/Windows";
                                                                     "/Program Files";
                                                                     "/Program Files (x86)";
                                                                     "/ProgramData";
                                                                     "/System Volume Information";
                                                                     "/Users/*/AppData";
                                                                     "/Recovery";
                                                                     "/var";
                                                                     "/usr";
                                                                     "/sys";
                                                                     "/proc";
                                                                     "/lib";
                                                                     "/grub";
                                                                     "/grub2";
                                                                     "/opt";
                                                                     "/splunk"
                                                                 )
                                            }
                     }
}

$newprol = api post -v2 data-protect/protection-groups $myObject
