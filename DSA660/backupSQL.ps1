# usage: ./backupSQL.ps1 -vip mycluster -username myusername -password mypassword -Name "jobname" -storageDomainName -policy name

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password  
    [Parameter()][string]$storageDomainName = 'sd-idd-ic',  # local or AD domain password  
    [Parameter(Mandatory = $True)][string]$name,  # name of backup
    [Parameter()][string]$policyName = 'SQL' #name of policy
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

Connect-CohesityCluster -Server cohesity-a.cohesitylabs.az -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "LOCAL\admin", (ConvertTo-SecureString -AsPlainText "cohesity123" -Force))
$SQL = Get-CohesityMSSQLObject

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

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

$mysqlObject = @{
    "policyId" = $policy.id;
    "startTime" = @{
                      "hour" = 20;
                      "minute" = 23;
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
    "name" = "$name";
    "environment" = "kSQL";
    "isPaused" = $false;
    "description" = "";
    "alertPolicy" = @{
                        "backupRunStatus" = @(
                                                "kFailure"
                                            );
                        "alertTargets" = @(

                                         )
                    };
    "mssqlParams" = @{
                        "protectionType" = "kFile";
                        "fileProtectionTypeParams" = @{
                                                         "performSourceSideDeduplication" = $false;
                                                         "fullBackupsCopyOnly" = $false;
                                                         "userDbBackupPreferenceType" = "kBackupAllDatabases";
                                                         "backupSystemDbs" = $true;
                                                         "useAagPreferencesFromServer" = $true;
                                                         "objects" = @(
                                                                         @{
                                                                             "id" = ($SQL |?{$_.Name -eq "MSSQLSERVER/Cohesity_DB1"}).Id
                                                                         }
                                                                     )
                                                     }
                    }
}
$newsqlbackup = api post -v2 data-protect/protection-groups $mysqlObject
