<#
Academy Labs Cohesity Replication To CloudArchive Prepare
-----------------------------------------------------------------
This script sets the required GFlags for archiving replicas on the cohesity-02 cluster.

Arguments:
None

Required Modules:
None
#>
#Verify and process arguments passed to the script

Write-Output "Verifying arguments passed from script launcher ..."
$passedArguments = $args[0]
$passedArguments = $scriptArgs -split(",")
$arraySize = $passedArguments.Count
[int]$counter = 1
if ($arraySize -gt 0) {
    Write-Output "   Arguments Passed To Script:"
    #Process arguments
    foreach ($arg in $passedArguments) {
        New-Variable -Name "var$counter" -Value $arg -Scope "Private"
        $value = Get-Variable -Name "var$counter" -ValueOnly
        Write-Output "      var$counter = $value"
        $counter++
    }
} else {
    Write-Output "   Script Arguments: No arguments to process"
}

#Script variables
$cohesity02ApiUrlv1 = "https://cohesity-b.cohesitylabs.az/irisservices/api/v1"
$cohesity02Name = "cohesity-b"
$cohesityClusterUsername = "admin"
$cohesityClusterPassword = "cohesity123"
$cohesityClusterDomain = "local"

#Get access token for cohesity-02
Write-Output "`nConnecting to $cohesity02Name cluster ..."
$payload = @{
    "domain" = "$cohesityClusterDomain";
    "password" = "$cohesityClusterPassword";
    "username" = "$cohesityClusterUsername";
} | ConvertTo-Json
$cohesityHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$cohesityHeader.Add("accept", "application/json")
$response = Invoke-RestMethod -Method POST -Uri "$cohesity02ApiUrlv1/public/accessTokens" -Headers $cohesityHeader -ContentType "application/json" -Body $payload
$cohesity02AccessToken = $response.accessToken
Write-Output "   Connected to $cohesity02Name cluster"

#Create authorized header
$cohesity02AuthorizedHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$cohesity02AuthorizedHeader.Add("Authorization", "Bearer $cohesity02AccessToken")
$cohesity02AuthorizedHeader.Add("accept", "application/json")

#Get cohesity-02 cluster ID and incarnation ID
Write-Output "`nFetching cluster info for $cohesity02Name ..."
$response = Invoke-RestMethod -Method GET -Uri "$cohesity02ApiUrlv1/public/cluster" -Headers $cohesity02AuthorizedHeader
$cohesity02ClusterId = $response.id
$cohesity02IncarnationId = $response.incarnationId
Write-Output "   Cluster ID: $cohesity02ClusterId"
Write-Output "   Incarnation ID: $cohesity02IncarnationId"

#Set gflags for cascaded replication to archive on cohesity-02
Write-Output "`nSetting Gflags on the $cohesity02Name cluster ..."
$payload = @{
    "clusterId" = [int64]$cohesity02ClusterId;
    "serviceName" = "magneto";
    "gflags" = @(
        @{
            "name" = "magneto_master_ignore_oob_copy_for_archival";
            "value" = "false";
            "reason" = "archive replica";
        }
    );
} | ConvertTo-Json -Depth 50
$response = Invoke-RestMethod -Method POST -Uri "$cohesity02ApiUrlv1/nexus/cluster/update_gflags" -Headers $cohesity02AuthorizedHeader -ContentType "application/json" -Body $payload
Write-Output "   Set GFlag:"
Write-Output "      Service: magneto"
Write-Output "      Name: magneto_master_ignore_oob_copy_for_archival"
Write-Output "      Value: false"
$payload = @{
    "clusterId" = [int64]$cohesity02ClusterId;
    "serviceName" = "magneto";
    "gflags" = @(
        @{
            "name" = "magneto_master_restrict_inactive_job_update";
            "value" = "false";
            "reason" = "archive replica";
        }
    );
} | ConvertTo-Json -Depth 50
$response = Invoke-RestMethod -Method POST -Uri "$cohesity02ApiUrlv1/nexus/cluster/update_gflags" -Headers $cohesity02AuthorizedHeader -ContentType "application/json" -Body $payload
Write-Output "   Set GFlag:"
Write-Output "      Service: magneto"
Write-Output "      Name: magneto_master_restrict_inactive_job_update"
Write-Output "      Value: false"
$payload = @{
    "clusterId" = [int64]$cohesity02ClusterId;
    "serviceName" = "bridge";
    "gflags" = @(
        @{
            "name" = "icebox_allow_archive_now_archives_as_reference_and_base";
            "value" = "true";
            "reason" = "archive replica";
        }
    );
} | ConvertTo-Json -Depth 50
$response = Invoke-RestMethod -Method POST -Uri "$cohesity02ApiUrlv1/nexus/cluster/update_gflags" -Headers $cohesity02AuthorizedHeader -ContentType "application/json" -Body $payload
Write-Output "   Set GFlag:"
Write-Output "      Service: bridge"
Write-Output "      Name: icebox_allow_archive_now_archives_as_reference_and_base"
Write-Output "      Value: true"
$payload = @{
    "clusterId" = [int64]$cohesity02ClusterId;
    "serviceName" = "iris";
    "gflags" = @(
        @{
            "name" = "iris_ui_flags";
            "value" = "editRunForInactiveJobsEnabled=true";
            "reason" = "archive replica";
        }
    );
} | ConvertTo-Json -depth 50
$response = Invoke-RestMethod -Method POST -Uri "$cohesity02ApiUrlv1/nexus/cluster/update_gflags" -Headers $cohesity02AuthorizedHeader -ContentType "application/json" -Body $payload
Write-Output "   Set GFlag:"
Write-Output "      Service: iris"
Write-Output "      Name: iris_ui_flags"
Write-Output "      Value: editRunForInactiveJobsEnabled=true"

#Restart services
Write-Output "`nRestarting Iris and Magneto services on the $cohesity02Name cluster ..."
$payload = @{
    "clusterId" = [int64]$cohesity02ClusterId;
    "services" = @(
        "iris"
        "magneto"
    );
} | ConvertTo-Json -depth 50
$response = Invoke-RestMethod -Method POST -Uri "$cohesity02ApiUrlv1/nexus/cluster/restart" -Headers $cohesity02AuthorizedHeader -ContentType "application/json" -Body $payload
$message = $response.message
Write-Output "   $message"
Start-Sleep 10

#Wait for service restart to complete
Write-Output "`nVerifying service restart on the $cohesity02Name cluster ..."
$serviceRestartStatus = 0
$timer = 0
while ($serviceRestartStatus -eq 0) {
    try {
        $response = Invoke-RestMethod -Method GET -Uri "$cohesity02ApiUrlv1/public/cluster/status" -Headers $cohesity02AuthorizedHeader
        $cohesityClusterCurrentOperation = $response.currentOperation
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
