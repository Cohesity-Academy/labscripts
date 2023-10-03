<#
Required Modules:
Brian Seltzer's script libraries installed in c:\Windows\TechAccelerator\Cohesity\bseltz\powershell\

Add the remote cluster relationship between cohesity-01 and 02 - add_remote_cluster.ps1  Task actions 
 Create an SMB-only view "CohesityReplicatedSMBView" on cohesity-01. This view cannot have local user access rights, they must be all domain users, otherwise failover cannot 
	complete because the destination will not understand the SIDs with rights to the view. 
 Create a cname DNS record that points to cohesity-01 called "cohesityviews" 
 Map a network drive on the jump box to \cohesityviews\CohesityReplicatedSMBView
 Create a dataset on the mapped drive - I did 99 text files using a simple "for" loop, but as long as there are > 20 or so files they can be anything.
 Create a protection policy on cohesity-01 that replicates to 02
 Create a protection group (aka protection job) that protects the SMB-only view created above using the protection policy created above
 Run the protection group (job) created above, and allow replication to complete - run_job.ps1
 
cd \
cd cohesity
.\talabs_script_launcher_v2.ps1 -scriptFolder smartfiles -scriptName talabs_coh_failover -scriptArgs "ASPrepFailover" -noExit true 

cd \
cd cohesity
.\talabs_script_launcher_v2.ps1 -scriptFolder smartfiles -scriptName talabs_coh_failover -scriptArgs "ASDoFailover" -noExit true 

cd \
cd cohesity
.\talabs_script_launcher_v2.ps1 -scriptFolder smartfiles -scriptName talabs_coh_failover -scriptArgs "ASUpdateCname" -noExit true 


#>

######################################################
# Process arguments passed to the script
######################################################

Write-Output "Verifying arguments passed from script launcher ..." | Out-File $clog -Append
$passedArguments = $args[0]
$passedArguments = $scriptArgs -split(",")
$arraySize = $passedArguments.Count
[int]$counter = 1
if ($arraySize -gt 0) {
    Write-Output "   Arguments Passed To Script:" | Out-File $clog -Append
    #Process arguments
    foreach ($arg in $passedArguments) {
        New-Variable -Name "var$counter" -Value $arg -Scope "Private"
        $value = Get-Variable -Name "var$counter" -ValueOnly
        Write-Output "      var$counter = $value" | Out-File $clog -Append
        $counter++
    }
} else {
    Write-Output "   Script Arguments: No arguments to process" | Out-File $clog -Append
}

######################################################
# Make Static Assignments
######################################################

$cohesity01ApiUrlv1 = "https://cohesity-01.talabs.local/irisservices/api/v1"
$cohesity01ApiUrlv2 = "https://cohesity-01.talabs.local/v2"
$cohesity02ApiUrlv1 = "https://cohesity-02.talabs.local/irisservices/api/v1"
$cohesity02ApiUrlv2 = "https://cohesity-02.talabs.local/v2"
$cohesity01Name = "cohesity-01"
$cohesity02Name = "cohesity-02"
$cohesity01IP = "172.16.3.101"
$cohesity02IP = "172.16.3.102"
$defaultSDName = "DefaultStorageDomain"
$viewName = "CohesityReplicatedSMBView"
$policyName = "Replicated Policy"
$daysToKeep = 30
$replicateTo = "cohesity-02"
$jobName = "ReplicatedSMBViewGroup"

$cohesityClusterUsername = "admin"
$cohesityClusterPassword = "TechAccel1!"
$cohesityClusterDomain = "local"

$functionToExecute = $var1

######################################################
# Get access token for cohesity-01
######################################################

Write-Output "`nConnecting to $cohesity01Name cluster ..." | Out-File $clog -Append
$payload = @{
    "domain" = "$cohesityClusterDomain";
    "password" = "$cohesityClusterPassword";
    "username" = "$cohesityClusterUsername";
} | ConvertTo-Json
$cohesityHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$cohesityHeader.Add("accept", "application/json")
$response = Invoke-RestMethod -Method POST -Uri "$cohesity01ApiUrlv1/public/accessTokens" -Headers $cohesityHeader -ContentType "application/json" -Body $payload
$cohesity01AccessToken = $response.accessToken
Write-Output "   Connected to $cohesity01Name cluster" | Out-File $clog -Append

######################################################
# Create cohesity-01 authorized header
######################################################

$cohesity01AuthorizedHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$cohesity01AuthorizedHeader.Add("Authorization", "Bearer $cohesity01AccessToken")
$cohesity01AuthorizedHeader.Add("accept", "application/json")

######################################################
# Get access token for cohesity-02
######################################################

Write-Output "`nConnecting to $cohesity02Name cluster ..." | Out-File $clog -Append
$payload = @{
    "domain" = "$cohesityClusterDomain";
    "password" = "$cohesityClusterPassword";
    "username" = "$cohesityClusterUsername";
} | ConvertTo-Json
$cohesityHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$cohesityHeader.Add("accept", "application/json")
$response = Invoke-RestMethod -Method POST -Uri "$cohesity02ApiUrlv1/public/accessTokens" -Headers $cohesityHeader -ContentType "application/json" -Body $payload
$cohesity02AccessToken = $response.accessToken
Write-Output "   Connected to $cohesity02Name cluster" | Out-File $clog -Append

######################################################
# Create cohesity-02 authorized header
######################################################

$cohesity02AuthorizedHeader = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$cohesity02AuthorizedHeader.Add("Authorization", "Bearer $cohesity02AccessToken")
$cohesity02AuthorizedHeader.Add("accept", "application/json")

##################################
# Helper Functions
##################################

function Get-02-View-Obj {
	$response = Invoke-RestMethod -Method GET -Uri "$cohesity02ApiUrlv2/file-services/views" -Headers $cohesity02AuthorizedHeader -ContentType "application/json" 
	$result = $response.views | Where-Object { $_.name -eq $viewName }
	return $result
}

##################################
# Autoscript Functions
##################################

function ASPrepFailover {
	$viewObj = Get-02-View-Obj
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
	$params = $params | ConvertTo-Json -Depth 99
	$response = Invoke-RestMethod -Method POST -Uri "$cohesity02ApiUrlv2/data-protect/failover/views/$viewID" -Headers $cohesity02AuthorizedHeader -ContentType "application/json" -Body $params
}

function ASDoFailover {
	$viewObj = Get-02-View-Obj
	$viewID = $viewObj.viewId
	$params = @{
		"type" = "Planned";
		"plannedFailoverParams" = @{
			"type" = "Finalize";
			"preparePlannedFailverParams" = @{}
		}
	}
	$params = $params | ConvertTo-Json -Depth 99
	$response = Invoke-RestMethod -Method POST -Uri "$cohesity02ApiUrlv2/data-protect/failover/views/$viewID" -Headers $cohesity02AuthorizedHeader -ContentType "application/json" -Body $params
}

function ASUpdateCnameOld {
	$cname = "cohesityviews"
	$domain = "talabs.local"
	$oldHost = "cohesity-01"
	$newHost = "cohesity-02"
	$newRecord = $newHost

	$oldCnameRecord = Get-DnsServerResourceRecord -ZoneName $domain -ComputerName $domain -Name $cname
	$newCnameRecord = $oldCnameRecord.Clone()
	if($newRecord -match $domain){
		$newCnameRecord.RecordData.HostNameAlias = $newRecord
	}else{
		$newCnameRecord.RecordData.HostNameAlias = "{0}.{1}." -f $newRecord, $domain
	}
	$null = Set-DnsServerResourceRecord -NewInputObject $newCnameRecord -OldInputObject $oldCnameRecord -ZoneName $domain -ComputerName $domain -PassThru

	$spn = "{0}.{1}" -f $cname, $domain
	$oldHost = $oldHost.split('.')[0]
	Set-ADComputer -Identity $oldHost -ServicePrincipalNames @{Remove="cifs/$spn"}
	Set-ADComputer -Identity $oldHost -ServicePrincipalNames @{Remove="cifs/$cname"}

	$newHost = $newHost.split('.')[0]
	Set-ADComputer -Identity $newHost -ServicePrincipalNames @{Add="cifs/$spn"}
	Set-ADComputer -Identity $newHost -ServicePrincipalNames @{Add="cifs/$cname"}
}

function ASUpdateCname {
	$cname = "cohesityviews"
	$domain = "talabs.local"
	$oldHost = "cohesity-01"
	$newHost = "cohesity-02"
	
	$oldCnameRecord = Get-DnsServerResourceRecord -ZoneName $domain -ComputerName $domain -Name $cname
	$newCnameRecord = $oldCnameRecord.Clone()
	$newCnameRecord.RecordData.HostNameAlias = $newHost
	Set-DnsServerResourceRecord -NewInputObject $newCnameRecord -OldInputObject $oldCnameRecord -ZoneName $domain -ComputerName $domain
}

######################################################
# Main executes the function name passed as the final parameter.
######################################################

$validFunctions = @("ASPrepFailover", "ASDoFailover", "ASUpdateCname")
if ($validFunctions.Contains($functionToExecute)) {
	& $functionToExecute
} else {
	$options = $validFunctions -join ","
	Write-Output "Invalid function: $functionToExecute specified. Choose one of the following: $options" | Out-File $clog -Append
}
