### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'cohesity-a.cohesitylabs.az',  # endpoint to connect to
    [Parameter()][string]$username = 'admin',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,  # use API key authentication
    [Parameter()][string]$password = 'cohesity123',  # send password / API key via command line (not recommended)
    [Parameter()][switch]$noPrompt,  # do not prompt for password
    [Parameter()][switch]$mcm,  # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,  # MFA code
    [Parameter()][switch]$emailMfaCode,  # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][array]$pause,
    [Parameter()][array]$resume,
    [Parameter()][array]$terminate,
    [Parameter()][switch]$wait
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -password $password -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

Write-Output "Getting views on Cohesity-A cluster ..." 
$views_json = api get views

Write-Output "Checking available apps on the Cohesity-A cluster ..." 
$installed_apps_json = api get apps 

Write-Output "Starting Insight Cohesity-A cluster ..."
$insight_view = ($views_json.views.name -like "*insight*")
$insight_view_id = ($views_json.views |?{$_.name -like "*insight*"}).viewid
$insight_view_id = $insight_view_id
 
$app_uid = ($installed_apps_json |?{$_.metadata.name -eq "Insight"}).appId
$version = ($installed_apps_json |?{$_.metadata.name -eq "Insight"}).version
$guid = New-Guid

$insight_view_id.GetType()

$myObject = @{ 
    "creationUid" = "$guid";
    "appUid" = $app_uid;
    "appVersion" = $version;
    "description" = "";
    "settings" = @{
    "vmNumReplicasList" = "[]";
    "qosTier" = "kLow";
    "protectedObjectPrivileges" = @{
        "protectedObjectPrivilegesType" = "kNone"
        };
        "readViewPrivileges" = @{
        "privilegesType" = "kSpecific";
        "viewIds" = "[$insight_view_id]"
        };
        "readWriteViewPrivileges" = @{
        "privilegesType" = "kSpecific";
        "viewIds" = "[]"
        }
    }
}
          


api post appInstances $myObject
