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
    "serviceName" = "secure-shell";
    "gflags" = @(
        @{
            "name" = "enable";
            "value" = "false";
        }
    );
} 

$response1 = api POST /nexus/cluster/update_gflags $payload1

Write-Output "`nAll Gflags have been set and service restarts are complete"
