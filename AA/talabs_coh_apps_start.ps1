<#
TechAccelerator Labs App Start and Stop
-------------------------------------
This script starts and stops apps on the TA VM Cohesity-A.

The blue button to call this would be as follows:
 
<button class="btn btn-primary" onclick="ConsolePaste('cd\\\ncd cohesity\n.\\talabs_script_launcher.ps1 coh_apps_start 651,SpotLight\n')" type="button">Start SpotLight App</button>
 
All arguments are a csv list. The first one has to be the DataPlatform version (651 or 641) – this is needed as the default password for the cluster is different.  

The second argument you can pass is the app name.  These arguments are processed dynamically by the script and assigned arbitrary numbers (var1, var2, etc.).

Copyright Cohesity. 
Authors Jay White and Jay Goldfinch
#>

#Script inputs 
$cohesityArguments = $args[0]

#Script execution started
Write-Output "`nSCRIPT STARTED ($date)" | Out-File $clog -Append
Write-Output "SCRIPT STARTED ($date)" | Out-File $clog -Append

Write-Output "`nProcessing arguments $cohesityArguments..." | Out-File $clog -Append
#Process Cohesity arguments (if any)
$cohesityArguments = $cohesityArguments -split(",")
$arraySize = $cohesityArguments.Count
[int]$counter = 1
if ($arraySize -gt 0) {
    #Process arguments
    foreach ($i in $cohesityArguments) {
        New-Variable -Name "var$counter" -Value $i
        $value = Get-Variable -Name "var$counter" -ValueOnly
        Write-Output "var$counter = $value" | Out-File $clog -Append
        $counter++
    }
} else {
    Write-Output "No arguments to process" | Out-File $clog -Append
}
Write-Output "Finished processing arguments" | Out-File $clog -Append

#Global variables
$dpVersion = Get-Variable -Name "var1" -ValueOnly
$restApiRootUrlCoh1 = "https://Cohesity-A.cohesitylabs.az/irisservices/api/v1/public"
$targetApp = Get-Variable -Name "var2" -ValueOnly

#Get access token for Cohesity-A
Write-Output "`nConnecting to Cohesity-A cluster ..." | Out-File $clog -Append
Write-Output "Getting access token" | Out-File $clog -Append
if ($dpVersion -match "650") {
    $response = & "curl.exe" "--ssl-no-revoke" -X POST "$restApiRootUrlCoh1/accessTokens" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \`"domain\`": \`"local\`", \`"password\`": \`"admin\`", \`"username\`": \`"admin\`"}"
} else {
    if ($dpVersion -match "651") {
        $response = & "curl.exe" "--ssl-no-revoke" -X POST "$restApiRootUrlCoh1/accessTokens" -H "accept: application/json" -H "Content-Type: application/json" -d "{ \`"domain\`": \`"local\`", \`"password\`": \`"cohesity123\`", \`"username\`": \`"admin\`"}"
    } else {
        Write-Output "ERROR: Could not determine DataPlatform version for lab instance!" | Out-File $clog -Append
        Write-Output "ERROR: Could not determine DataPlatform version for lab instance!" | Out-File $clog -Append
    }
}
Write-Output "Response:`n$response" | Out-File $clog -Append
$response = $response -split "`""
$cohesityAccessTokenCoh1 = $response[3]
Write-Output "Cohesity-A Access token: $cohesityAccessTokenCoh1" | Out-File $clog -Append
Write-Output "Connected to Cohesity-A cluster" | Out-File $clog -Append

Function GetInstalledApps{
    Write-Output "`nChecking available apps on the Cohesity-A cluster ..." | Out-File $clog -Append
    $installed_apps_raw = & "curl.exe" "--ssl-no-revoke" -X GET "$restApiRootUrlCoh1/apps" -H "Authorization: Bearer $cohesityAccessTokenCoh1" -H "accept: application/json"
    $installed_apps_json = ConvertFrom-Json -InputObject $installed_apps_raw
    return $installed_apps_json
}

Function GetAppInstances{
    Write-Output "`nChecking running app instances on the Cohesity-A cluster ..." | Out-File $clog -Append
    $app_instances_raw = & "curl.exe" "--ssl-no-revoke" -X GET "$restApiRootUrlCoh1/appInstances" -H "Authorization: Bearer $cohesityAccessTokenCoh1" -H "accept: application/json"
    $app_instances_json = ConvertFrom-Json -InputObject $app_instances_raw
    return $app_instances_json
}

Function StopApps {
    GetAppInstances | ForEach-Object {
        if ($_.state -ne 'kTerminating' -AND $_.state -ne 'kTerminated') {
            $inst_id = $_.appInstanceId
            $termination_str = & "curl.exe" "--ssl-no-revoke" -X PUT "$restApiRootUrlCoh1/appInstances/$inst_id/states" -H "Authorization: Bearer $cohesityAccessTokenCoh1" -H "accept: application/json" -d "{ \`"state\`": \`"kTerminated\`"}"
            Write-Output "`nGot this response when terminating app: $termination_str..." | Out-File $clog -Append
        }
    }
}

Function AwaitAppStop {
    $done = 0 
    DO {
        Start-Sleep -Seconds 5
        $done = 1
        GetAppInstances | ForEach-Object {
            $my_state = $_.state
            Write-Output "`nApp state: $my_state..." | Out-File $clog -Append
            if ($_.state -eq 'kTerminating') {
                $done = 0
            }
        }
    } While (-NOT $done)
}


Function StartClamAV {
    GetInstalledApps | ForEach-Object {
        if ($_.metadata.name -eq "ClamAV") {
            $app_uid = $_.appId
            $version = $_.version
            $guid = New-Guid
            $start_str = & "curl.exe" "--ssl-no-revoke" -X POST "$restApiRootUrlCoh1/appInstances" -H "Authorization: Bearer $cohesityAccessTokenCoh1" -H "accept: application/json" -d "{ \`"creationUid\`": \`"$guid\`", \`"appUid\`": $app_uid, \`"appVersion\`": $version, \`"description\`": \`"\`", \`"settings\`": {\`"vmNumReplicasList\`": [], \`"qosTier\`": \`"kLow\`", \`"protectedObjectPrivileges\`": {\`"protectedObjectPrivilegesType\`": \`"kNone\`"}}}"
            Write-Output "`nGot this response when starting ClamAV: $start_str..." | Out-File $clog -Append
        }
    }
}

Function StartSpotlight {    
    GetInstalledApps | ForEach-Object {
    if ($_.metadata.name -eq "Spotlight") {
        $app_uid = $_.appId
        $version = $_.version
        $guid = New-Guid
        $start_str = & "curl.exe" "--ssl-no-revoke" -X POST "$restApiRootUrlCoh1/appInstances" -H "Authorization: Bearer $cohesityAccessTokenCoh1" -H "accept: application/json" -d "{ \`"creationUid\`": \`"$guid\`", \`"appUid\`": $app_uid, \`"appVersion\`": $version, \`"description\`": \`"\`", \`"settings\`": {\`"vmNumReplicasList\`": [], \`"qosTier\`": \`"kLow\`", \`"protectedObjectPrivileges\`": {\`"protectedObjectPrivilegesType\`": \`"kNone\`"}}}"
        Write-Output "`nGot this response when starting Spotlight: $start_str..." | Out-File $clog -Append
        }
    }
}

Function GetViews {
    Write-Output "`nGetting views on Cohesity-A cluster ..." | Out-File $clog -Append
    $views_raw = & "curl.exe" "--ssl-no-revoke" -X GET "$restApiRootUrlCoh1/views" -H "Authorization: Bearer $cohesityAccessTokenCoh1" -H "accept: application/json"
    $views_json = ConvertFrom-Json -InputObject $views_raw
    return $views_json.views
}

Function GetInsightView {
    GetViews | ForEach-Object {
        Write-Output "`nExamining view $_ ..." | Out-File $clog -Append
        if ($_.name -like "*insight*") {
            return $_
            }
        }
}

Function StartInsight {
    $insight_view = GetInsightView
    $insight_view_id = $insight_view.viewId
    Write-Output "`nStarting with insight view ID $insight_view_id..." | Out-File $clog -Append
    GetInstalledApps | ForEach-Object {
        if ($_.metadata.name -eq "Insight") {
            $app_uid = $_.appId
            $version = $_.version
            $guid = New-Guid
            $start_str = & "curl.exe" "--ssl-no-revoke" -X POST "$restApiRootUrlCoh1/appInstances" -H "Authorization: Bearer $cohesityAccessTokenCoh1" -H "accept: application/json" -d "{ \`"creationUid\`": \`"$guid\`", \`"appUid\`": $app_uid, \`"appVersion\`": $version, \`"description\`": \`"\`", \`"settings\`": {\`"vmNumReplicasList\`": [], \`"qosTier\`": \`"kLow\`", \`"protectedObjectPrivileges\`": {\`"protectedObjectPrivilegesType\`": \`"kNone\`"}, \`"readViewPrivileges\`": {\`"privilegesType\`": \`"kSpecific\`", \`"viewIds\`": [$insight_view_id]}, \`"readWriteViewPrivileges\`": {\`"privilegesType\`": \`"kSpecific\`", \`"viewIds\`": []}}}"
            Write-Output "`nGot this response when starting Insight: $start_str..." | Out-File $clog -Append
            }
    }
}

StopApps
AwaitAppStop

if ($targetApp -eq "ClamAV") {
    StartClamAV
} elseif ($targetApp -eq "Spotlight") {
    StartSpotlight
} elseif ($targetApp -eq "Insight") {
    StartInsight
} else {
    Write-Output "`nUnsupported target app: $targetApp" | Out-File $clog -Append
}

#Script exceution complete
Write-Output "`nSCRIPT COMPLETED" | Out-File $clog -Append
Write-Output "SCRIPT COMPLETED" | Out-File $clog -Append
