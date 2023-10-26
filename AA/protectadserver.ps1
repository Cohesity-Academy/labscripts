# usage: ./protectadserver.ps1 -vip clusername -username admin -password password -adserver servername

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip = "cohesity-a.cohesitylabs.az",  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username = "admin",  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password = "cohesity123", # local or AD domain password
    [Parameter(Mandatory = $false)][string]$name = "AD Protect", # name of policy
    [Parameter(Mandatory = $false)][string]$policyName = "bronze", # name of policy
    [Parameter(Mandatory = $false)][string]$source = "ad-server-1.cohesitylabs.az",  # name of source
    [Parameter(Mandatory = $false)][string]$sdomain = "sd-idd-ic"  # name of source
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

$policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
$polid = $policy.id

$sdomains = api get viewBoxes
$stordomain = ($sdomains |?{$_.name -eq "$sdomain"}).id

$sources = api get protectionSources/registrationInfo
$sourceid = ($sources.rootNodes.rootNode |?{$_.name -eq "$source"}).id


$myObject = @{
    "policyId" = "$polid";
    "startTime" = @{
                      "hour" = 15;
                      "minute" = 34;
                      "timeZone" = "America/New_York"
                  };
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
    "storageDomainId" = $stordomain;
    "name" = "$name";
    "environment" = "kAD";
    "alertPolicy" = @{
                        "backupRunStatus" = @(
                                                "kFailure"
                                            )
                    };
    "adParams" = @{
                     "indexingPolicy" = @{
                                            "enableIndexing" = $false
                                        };
                     "objects" = @(
                                     @{
                                         "sourceId" = $sourceid;
                                         "appParams" = @(
                                                           @{
                                                               "appId" = 87
                                                           }
                                                       )
                                     }
                                 )
                 }
}

api POST -v2 data-protect/protection-groups $myObject
