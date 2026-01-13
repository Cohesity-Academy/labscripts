# usage: ./hypervprotection.ps1 -vip clusername -username admin -password password -Name "" -server ""

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password
    [Parameter()][array]$server = '',  # optional name of one server protect
    [Parameter(Mandatory = $True)][string]$name,  # name of policy
    [Parameter()][string]$startTime = '20:00',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',
    [Parameter()][string]$policyName
    )

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

    # parse startTime
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
        exit
    }

    # policy
    if(!$policyName){
        Write-Host "-policyName required when creating new job" -ForegroundColor Yellow
        exit
    }

    $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
    if(!$policy){
        Write-Host "Policy $policyName not found" -ForegroundColor Yellow
        exit
    }
    
    # get storageDomain
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

    
$myObject = @{
    "policyId" = $policy.id;
    "startTime" = @{
            "hour" = [int]$hour;
            "minute" = [int]$minute;
            "timeZone" = $timeZone
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
    "storageDomainId" = $viewBox.id;
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
