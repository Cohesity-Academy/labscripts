# usage: ./tryingprotection.ps1 -vip clusername -username admin -password password -Name ""

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password
    [Parameter(Mandatory = $True)][string]$name,  # name of protectiongroup
    [Parameter(Mandatory = $True)][string]$storageDomainName = 'sd-idd-ic',
    [Parameter(Mandatory = $True)][string]$policyName, # name of policy
    [Parameter(Mandatory = $True)][string]$dasource = "\\ad-server-1.cohesitylabs.az\Home_dir\Penny"  # name of source
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

$policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
    if(!$policy){
        Write-Host "Policy $policyName not found" -ForegroundColor Yellow
        exit
}


    $viewBoxes = api get viewBoxes
    if($viewBoxes -is [array]){
            $viewBox = $viewBoxes | Where-Object { $_.name -ieq $storageDomainName }
            if (!$viewBox) { 
                write-host "Storage domain $storageDomainName not Found" -ForegroundColor Yellow
                exit
            }
    }else{
        $viewBox = $viewBoxes[0]
    }

$sources = api get protectionSources/registrationInfo
$daid = ($sources.rootNodes.rootNode |?{$_.name -eq "$dasource"}).id

$myObject = @{
    "policyId" = "$policy.id";
    "startTime" = @{
                      "hour" = 18;
                      "minute" = 2;
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
    "storageDomainId" = $viewBox.id;
    "name" = "TESTPg1";
    "environment" = "kGenericNas";
    "alertPolicy" = @{
                        "backupRunStatus" = @(
                                                "kFailure"
                                            )
                    };
    "genericNasParams" = @{
                             "objects" = @(
                                             @{
                                                 "id" = 18
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


$newpol = api post -v2 "data-protect/protection-groups" $myObject
