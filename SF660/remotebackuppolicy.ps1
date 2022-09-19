# usage: ./remotebackupolicy.ps1 -vip clusername -username admin -password password -Name ""

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password,  # local or AD domain password
    [Parameter(Mandatory = $True)][string]$name  # name of policy
)

Connect-CohesityCluster -Server cohesity-a.cohesitylabs.az -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "LOCAL\admin", (ConvertTo-SecureString -AsPlainText "cohesity123" -Force)) | out-null
$out1 = Get-CohesityRemoteCluster
$clusterId = $out1.ClusterId
$clusterName = $out1.Name
$out2 = Get-CohesityVault -VaultName Az-Cool-Blob-Archive
$targetName = $out2.name
$targetID = $out2.id

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet


$policyParams = @{
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
                                                           "unit" = "Days";
                                                           "duration" = 14
                                                       }
                                     }
                     };
    "id" = $null;
    "name" = "$name";
    "description" = $null;
    "remoteTargetPolicy" = @{
                               "replicationTargets" = @(
                                                          @{
                                                              "copyOnRunSuccess" = $false;
                                                              "retention" = @{
                                                                                "unit" = "Days";
                                                                                "duration" = 14
                                                                            };
                                                              "schedule" = @{
                                                                               "unit" = "Runs"
                                                                           };
                                                              "targetType" = "RemoteCluster";
                                                              "remoteTargetConfig" = @{
                                                                                         "clusterId" = $clusterId;
                                                                                         "clusterName" = "$clusterName"
                                                                                     }
                                                          }
                                                      );
                               "archivalTargets" = @(
                                                       @{
                                                           "copyOnRunSuccess" = $false;
                                                           "retention" = @{
                                                                             "unit" = "Days";
                                                                             "duration" = 30
                                                                         };
                                                           "schedule" = @{
                                                                            "unit" = "Runs"
                                                                        };
                                                           "targetId" = $targetId;
                                                           "targetName" = "$targetName";
                                                           "targetType" = "Cloud"
                                                       }
                                                   )
                           };
    "retryOptions" = @{
                         "retries" = 3;
                         "retryIntervalMins" = 5
                     }
}


$newpol = api post -v2 data-protect/policies $policyParams
