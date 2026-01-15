# usage: ./protecthyperv.ps1 -vip clusername -username admin -password password -Name "" -server "" -vms "" -policyName "" -storageDomainName ""

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password
    [Parameter(Mandatory = $True)][string]$server = '',  # optional name of one server protect
    [Parameter(Mandatory = $true)][string[]]$vms = '',
    [Parameter(Mandatory = $True)][string]$name,  # name of protection group
    [Parameter()][string]$startTime = '20:00',
    [Parameter()][string]$timeZone = 'America/New_York',
    [Parameter()][int]$incrementalSlaMinutes = 60,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain',
    [Parameter(Mandatory = $True)][string]$policyName
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
    
    # get HyperV Server ID
    $protectionSources = api get protectionSources
    $hypervId = ($protectionSources.protectionSource |Where-Object { $_.name -eq $server }).id
    if (-not $hypervId) {
        throw "HyperV server '$server' not found"
    }

    # Normalize VM input
    $vms = $vms -join ',' -split '\s*,\s*' |
       Where-Object { $_ -and $_.Trim() } |
       ForEach-Object { $_.Trim() }
    
    # get HyperV VMs
    $vmSources = $protectionSources.nodes.protectionSource | Where-Object { $_.parentId -eq $hypervId }
    $vmMatches = $vmSources | Where-Object { $_.name -in $vms }

    # Validate VM existence
    $missingVMs = $vms | Where-Object { $_ -notin $vmMatches.name }
    if ($missingVMs) {
        throw "VM(s) not found under HyperV server '$server': $($missingVMs -join ', ')"
    }
    $hypervObjects = @(
        $vmMatches | ForEach-Object {
            @{
                "id" = $_.id
                "isAutoprotected" = $false
            }
        }
    )
    
    
$myObject = @{
    "policyId" = $policy.id;
    "startTime" = @{
        "hour"   = [int]$hour;
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
        "backupRunStatus" = @("kFailure"; "kSlaViolation");
        "alertTargets" = @()
    };
    "hypervParams" = @{
        "objects" = $hypervObjects;   # <--- HERE
        "excludeObjectIds" = @();
        "vmTagIds" = @();
        "excludeVmTagIds" = @();
        "protectionType" = "kAuto";
        "appConsistentSnapshot" = $false;
        "fallbackToCrashConsistentSnapshot" = $true;
        "indexingPolicy" = @{
            "enableIndexing" = $true;
            "includePaths" = @("/");
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

$myObject | ConvertTo-Json -Depth 20
$newprol = api post -v2 data-protect/protection-groups $myObject
