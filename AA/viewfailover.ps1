### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'cohesity-b.cohesitylabs.az',  # endpoint to connect to
    [Parameter()][string]$username = 'admin',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$password = 'cohesity123',  # send password / API key via command line (not recommended)
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][string]$viewName = 'CohesityReplicatedSMBView', # TargetApps: ClamAV, Insight or Spotlight
    [Parameter()][string]$jobname = 'test', # TargetApps: ClamAV, Insight or Spotlight
    [Parameter()][string]$vip2 = 'cohesity-a.cohesitylabs.az',  # endpoint to connect to
    [Parameter()][string]$username2 = 'admin',  # username for authentication / password storage
    [Parameter()][string]$domain2 = 'local',  # local or AD domain
    [Parameter()][string]$password2 = 'cohesity123',  # send password / API key via command line (not recommended)
    [Parameter()][string]$action = 'prepfailover'  # local or AD domain

)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -password $password -domain $domain


$response = api get -v2 file-services/views
$result = $response.views | Where-Object { $_.name -eq $viewName }

function PrepFailover{}
Connect-CohesityCluster -Server $vip2 -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$domain2\$username2", (ConvertTo-SecureString -AsPlainText "$password2" -Force))
suspend-cohesityprotectionjob -Name $jobname 
    $viewObj = $result
    $viewID = $viewObj.viewId
    $params = @{
        "type" = "Planned";
        "plannedFailoverParams" = @{
            "type" = "Prepare";
            "preparePlannedFailverParams" = @{
                "reverseReplication" = $False
            }
        }
    }
#    $params = $params | ConvertTo-Json -Depth 99
    api post -v2 data-protect/failover/views/$viewID $params

function DoFailover {
	$viewObj = $result
	$viewID = $viewObj.viewId
	$params = @{
		"type" = "Planned";
		"plannedFailoverParams" = @{
			"type" = "Finalize";
			"preparePlannedFailverParams" = @{}
		}
	}
	$params = $params | ConvertTo-Json -Depth 99
	api post -v2 data-protect/failover/views/$viewID $params
}


if ($action -eq "PrepFailover") {
    PrepFailover
} elseif ($action -eq "DoFailover") {
    DoFailover
} else {
    Write-Output "`nUnsupported target app: $targetApp" 
}



