# usage: ./backupSQL.ps1 -vip mycluster -username myusername -password mypassword -Name "policyname" 

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password  
    [Parameter(Mandatory = $True)][string]$name  # name of backup
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

Connect-CohesityCluster -Server cohesity-a.cohesitylabs.az -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "LOCAL\admin", (ConvertTo-SecureString -AsPlainText "cohesity123" -Force))
$SQL = Get-CohesityMSSQLObject

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

$mysqlObject = @{
    "policyId" = "8158516650510261:1575649096260:1";
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
    "storageDomainId" = 3203;
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
