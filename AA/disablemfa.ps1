# usage: ./cascade.ps1 -vip clusername -username admin -password password 

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter(Mandatory = $True)][string]$password # local or AD domain password
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password -quiet

$response = api GET cluster
$cohesityClusterId = $response.id
$cohesityIncarnationId = $response.incarnationId


$payload1 = @{
    "clusterId" = [int64]$cohesityClusterId;
    "serviceName" = "magneto";
    "gflags" = @(
        @{
            "name" = "magneto_master_ignore_oob_copy_for_archival";
            "value" = "false";
            "reason" = "archive replica";
        }
    );
} 

$response1 = api POST /nexus/cluster/update_gflags $payload1



$payload2 = @{
    "clusterId" = [int64]$cohesityClusterId;
    "serviceName" = "magneto";
    "gflags" = @(
        @{
            "name" = "magneto_master_restrict_inactive_job_update";
            "value" = "false";
            "reason" = "archive replica";
        }
    );
}

$response2 = api POST /nexus/cluster/update_gflags $payload2


$payload3 = @{
    "clusterId" = [int64]$cohesityClusterId;
    "serviceName" = "bridge";
    "gflags" = @(
        @{
            "name" = "icebox_allow_archive_now_archives_as_reference_and_base";
            "value" = "true";
            "reason" = "archive replica";
        }
    );
} 
$response3 = api POST /nexus/cluster/update_gflags $payload3


$payload4 = @{
    "clusterId" = [int64]$cohesityClusterId;
    "serviceName" = "iris";
    "gflags" = @(
        @{
            "name" = "iris_ui_flags";
            "value" = "editRunForInactiveJobsEnabled=true";
            "reason" = "archive replica";
        }
    );
}
$response4 = api POST /nexus/cluster/update_gflags $payload4


$payload5 = @{
    "clusterId" = [int64]$cohesityClusterId;
    "services" = @(
        "iris"
        "magneto"
    );
} 
$response5 = api POST /nexus/cluster/restart $payload5


start-sleep 10

Write-Output "`nVerifying service restart on the $vip cluster ..."
$serviceRestartStatus = 0
$timer = 0
while ($serviceRestartStatus -eq 0) {
    try {
        $response6 = api GET cluster/status 
        $cohesityClusterCurrentOperation = $response6.currentOperation
    } catch {}
    if ($cohesityClusterCurrentOperation -match "kNone") {
        Write-Output "   Cluster services have been restarted"
        $serviceRestartStatus = 1
        break
    } else {
        Write-Output "   Waiting for services to restart ($cohesityClusterCurrentOperation) ... $timer seconds elapsed ..."
        Start-Sleep -Seconds 5
        $timer = $timer + 5
    }
}

Write-Output "`nAll Gflags have been set and service restarts are complete"
