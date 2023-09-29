<#
Required Modules:
Brian Seltzer's script libraries installed in c:\Windows\TechAccelerator\Cohesity\bseltz\powershell\
#>
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'cohesity.cluster.local',  # endpoint to connect to
    [Parameter()][string]$username = 'admin',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$password = 'yourpassword',  # send password / API key via command line (not recommended)
    [Parameter()][string]$action = $null,  # cluster name to connect to when connected to Helios/MCM
)
#Verify and process arguments passed to the script
Write-Output "running $MyInvocation.MyCommand.Name ..." 

$action = $args[0]
Write-Output "action is $action ..." 

if ($action -eq "failover") {
	$vip = "cohesity-b"
} elseif ($action -eq "failback") {
	$vip = "cohesity-a"
} else {
	Write-Output "Invalid action specified: $action ..." 
}

#Script variables
$domain = "local"
$viewName = "SMB_Home_Drive"

cp $apiHelperFilePath .
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

apiauth -vip $vip -username $username -domain $domain -password $password

$views = api get views

$params = @{
	"type" = "Planned";
	"plannedFailoverParams" = @{
		"type" = "Prepare";
		"preparePlannedFailverParams" = @{
			"reverseReplication" = $False
		}
	}
}

$view = $views.views | Where-Object name -eq $viewName
$result = api post -v2 "data-protect/failover/views/$($view.viewId)" $params
