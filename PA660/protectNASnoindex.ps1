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

if(!$job){
    "Creating new protection group..."
    $newJob = $True

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

# get physical protection sources
$sources = api get protectionSources?environments=kGenericNas

$sourceIds = [array]($job.physicalParams.fileProtectionTypeParams.objects.id)
$newSourceIds = @()

foreach($server in $serversToAdd | Where-Object {$_ -ne ''}){
    $nas = $server.ToString()
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


$myObject = @{
    "policyId" = $policy.id;
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
    "storageDomainId" = $viewBox.id;
    "name" = $jobName;
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
                                                 "id" = $sourceId
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
