
# usage: ./tryingprotection.ps1 -vip clusername -username admin -password password -Name ""

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)][string]$vip = "cohesity-a.cohesitylabs.az",  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $false)][string]$username = "admin",  # username (local or AD)
    [Parameter(Mandatory = $false)][string]$password = "cohesity123",  # local or AD domain password
    [Parameter(Mandatory = $false)][string]$name = "NAS-CloudArchiveDirect",  # name of protectiongroup
    [Parameter(Mandatory = $false)][string]$policyName = "CloudArchiveDirect", # name of policy
    [Parameter(Mandatory = $false)][string]$dasource = "\\ad-server-1.cohesitylabs.az\Home_dir\Penny"  # name of source
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

$policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
$polid = $policy.id


$sources = api get protectionSources/registrationInfo
$daid = ($sources.rootNodes.rootNode |?{$_.name -eq "$dasource"}).id

$myObject = @{
    "policyId" = "$polid";
    "priority" = "kMedium";
    "sla" = @(
                @{
                    "backupRunType" = "kFull";
                    "slaMinutes" = 1440
                };
                @{
                    "backupRunType" = "kIncremental";
                    "slaMinutes" = 1440
                }
            );
    "qosPolicy" = "kBackupHDD";
    "abortInBlackouts" = $false;
    "storageDomainId" = $null;
    "name" = "$name";
    "environment" = "kGenericNas";
    "alertPolicy" = @{
                        "backupRunStatus" = @(
                                                "kFailure"
                                            )
                    };
    "genericNasParams" = @{
                             "objects" = @(
                                             @{
                                                 "id" = $daid
                                             }
                                         );
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
                                                };
                             "protocol" = "kNfs3";
                             "fileFilters" = @{
                                                 "includeList" = @(
                                                                     "/"
                                                                 );
                                                 "excludeList" = @(
                                                                     "/.snapshot/"
                                                                 )
                                             };
                             "excludeObjectIds" = @(

                                                  )
                         }
}


api POST -v2 data-protect/protection-groups $myObject
