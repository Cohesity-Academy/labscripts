### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'cohesity-a.cohesitylabs.az',  # endpoint to connect to
    [Parameter()][string]$username = 'admin',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$password = 'cohesity123',  # send password / API key via command line (not recommended)
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][string]$targetApp = 'Spotlight' # TargetApps: ClamAV, Insight or Spotlight
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -password $password -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

Write-Output "Getting views on $vip cluster ..." 
$views_json = api get views

Write-Output "Checking available apps on the $vip cluster ..." 
$installed_apps_json = api get apps 

Write-Output "Starting $targetApp $vip cluster ..."
$insight_view = ($views_json.views.name -like "*insight*")
$insight_view_id = ($views_json.views |?{$_.name -like "*insight*"}).viewid
[int]$insight_view_id = $insight_view_id
 
$app_uid = ($installed_apps_json |?{$_.metadata.name -eq "$targetApp"}).appId
$version = ($installed_apps_json |?{$_.metadata.name -eq "$targetApp"}).version
$guid = New-Guid


Function StartClamAV {
Write-Output "$app_uid"
    $myObject = @{ 
        "creationUid" = "$guid";
        "appUid" = $app_uid;
        "appVersion" = $version;
        "description" = "";
        "settings" = @{
            "vmNumReplicasList" = @();
            "qosTier" = "kLow";
            "protectedObjectPrivileges" = @{
                "protectedObjectPrivilegesType" = "kNone"
            }
        }
    }
    api post appInstances $myObject
}

Function StartSpotlight {
Write-Output "$app_uid"
    $myObject = @{ 
        "creationUid" = "$guid";
        "appUid" = $app_uid;
        "appVersion" = $version;
        "description" = "";
        "settings" = @{
        "vmNumReplicasList" = @();
        "qosTier" = "kLow";
        "protectedObjectPrivileges" = @{
            "protectedObjectPrivilegesType" = "kNone"
            }
        }
    }
    api post appInstances $myObject
}

Function StartInsight {
    $myObject = @{ 
        "creationUid" = "$guid";
        "appUid" = $app_uid;
        "appVersion" = $version;
        "description" = "";
        "settings" = @{
        "vmNumReplicasList" = @();
        "qosTier" = "kLow";
        "protectedObjectPrivileges" = @{
            "protectedObjectPrivilegesType" = "kNone"
            };
            "readViewPrivileges" = @{
            "privilegesType" = "kSpecific";
            "viewIds" = @($insight_view_id)
            };
            "readWriteViewPrivileges" = @{
            "privilegesType" = "kSpecific";
            "viewIds" = @()
            }
        }
    }
    api post appInstances $myObject
}


if ($targetApp -eq "ClamAV") {
    StartClamAV
} elseif ($targetApp -eq "Spotlight") {
    StartSpotlight
} elseif ($targetApp -eq "Insight") {
    StartInsight
} else {
    Write-Output "`nUnsupported target app: $targetApp" | Out-File $clog -Append
}


