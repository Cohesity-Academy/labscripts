[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter(Mandatory = $True)][string]$password, #username (local or AD)
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter(Mandatory = $True)][array]$servers = '',  # optional name of one server protect  
    [Parameter(Mandatory = $True)][string]$storageDomainName = 'DefaultStorageDomain',
    [Parameter(Mandatory = $True)][string]$policyName
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# get physical protection sources
$sources = api get protectionSources?environments=kPhysical

$sourceIds = [array]($job.physicalParams.fileProtectionTypeParams.objects.id)
$newSourceIds = @()

foreach($server in $serversToAdd | Where-Object {$_ -ne ''}){
    $server = $server.ToString()
    $node = $sources.nodes | Where-Object { $_.protectionSource.name -eq $server }
    if($node){
        if($node.registrationInfo.refreshErrorMessage -or $node.registrationInfo.authenticationStatus -ne 'kFinished'){
            Write-Warning "$server has source registration errors"
        }else{
            if($node.protectionSource.physicalProtectionSource.hostType -ne 'kLinux'){
                $sourceId = $node.protectionSource.id
                $newSourceIds += $sourceId
            }else{
                Write-Warning "$server is a Windows host"
            }
        }
    }else{
        Write-Warning "$server is not a registered source"
    }
}

foreach($sourceId in @([array]$sourceIds + [array]$newSourceIds) | Sort-Object -Unique){
    if($allServers -or $sourceId -in $newSourceIds){
        $params = $job.physicalParams.fileProtectionTypeParams.objects | Where-Object id -eq $sourceId
        $node = $sources.nodes | Where-Object { $_.protectionSource.id -eq $sourceId }
        Write-Host "processing $($node.protectionSource.name)"
        if(($null -eq $params) -or $replaceRules){
            $params = @{
                "id" = $sourceId;
                "name" = $node.protectionSource.name;
                "filePaths" = @();
                "usesPathLevelSkipNestedVolumeSetting" = $true;
                "nestedVolumeTypesToSkip" = $null;
                "followNasSymlinkTarget" = $false
            }
        }
    }
}

# gather list of servers to add to job
$serversToAdd = @()
foreach($server in $servers){
    $serversToAdd += $server
}
if ('' -ne $serverList){
    if(Test-Path -Path $serverList -PathType Leaf){
        $servers = Get-Content $serverList
        foreach($server in $servers){
            $serversToAdd += $server
        }
    }else{
        Write-Warning "Server list $serverList not found!"
        exit
    }
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

$job = @{
    "policyId" = $policy.id;
    "startTime" = @{
                      "hour" = 10;
                      "minute" = 44;
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
    "name" = $jobName;
    "environment" = "kPhysical";
    "isPaused" = $false;
    "description" = "";
    "alertPolicy" = @{
                        "backupRunStatus" = @(
                                                "kFailure"
                                            );
                        "alertTargets" = @(

                                         )
                    };
    "physicalParams" = @{
                           "protectionType" = "kVolume";
                           "volumeProtectionTypeParams" = @{
                                                              "objects" = @(
                                                                              @{
                                                                                  "id" = $sourceId;
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
                                                              "excludedVssWriters" = @(

                                                                                     );
                                                              "quiesce" = $false;
                                                              "continueOnQuiesceFailure" = $false;
                                                              "performSourceSideDeduplication" = $false;
                                                              "incrementalBackupAfterRestart" = $true
                                                          }
                       }
}

api post -v2 "data-protect/protection-groups" $job
