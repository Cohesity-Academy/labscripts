# usage: ./S3backupolicy.ps1 -vip clusername -username admin -password password -Name ""

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password
    [Parameter(Mandatory = $True)][string]$name  # name of policy
)

Connect-CohesityCluster -Server $vip -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "LOCAL\$username", (ConvertTo-SecureString -AsPlainText "$password" -Force)) | out-null
$out1 = Get-CohesityRemoteCluster
$clusterId = $out1.ClusterId
$clusterName = $out1.Name
$out2 = Get-CohesityVault -VaultName S3CloudStorage
$targetName = $out2.name
$targetID = $out2.id

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet


$policyParams2 = @{
    "backupPolicy" = @{
                         "regular" = @{
                                         "incremental" = @{
                                                             "schedule" = @{
                                                                              "unit" = "Days";
                                                                              "daySchedule" = @{
                                                                                                  "frequency" = 1
                                                                                              }
                                                                          }
                                                         };
                                         "retention" = @{
                                                           "unit" = "Weeks";
                                                           "duration" = 2
                                                       };
                                         "primaryBackupTarget" = @{
                                                                     "targetType" = "Archival";
                                                                     "archivalTargetSettings" = @{
                                                                                                    "targetId" = $targetID
                                                                                                }
                                                                 }
                                     }
                     };
    "id" = $null;
    "name" = "$name";
    "description" = $null;
    "remoteTargetPolicy" = @{

                           };
    "isCBSEnabled" = $false;
    "retryOptions" = @{
                         "retries" = 3;
                         "retryIntervalMins" = 5
                     }
}


$newpol = api post -v2 data-protect/policies $policyParams2
