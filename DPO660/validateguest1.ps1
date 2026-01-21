param(
    [string]$vip = "cohesity-a.cohesitylabs.az",
    [string]$username = "admin",
    [string]$password = "cohesity123"
)
# Ignore SSL errors for self-signed certs
$sslBypass = @'
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
'@
Add-Type -TypeDefinition $sslBypass
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
# Authenticate and get token
$authBody = @{
    domain = "LOCAL"
    username = $username
    password = $password
} | ConvertTo-Json
$authHeaders = @{
    "accept" = "application/json"
    "content-type" = "application/json"
}
$authUrl = "https://$vip/irisservices/api/v1/public/accessTokens"
try {
    $authResponse = Invoke-RestMethod -Uri $authUrl -Method Post -Body $authBody -Headers $authHeaders
    $token = $authResponse.accessToken
} catch {
    Write-Output "Could not authenticate to Cohesity. Please check your username, password, and cluster address."
    Write-Output "Incorrect"
    exit
}
$headers = @{
    "accept" = "application/json"
    "authorization" = "Bearer $token"
}
$errors = @()
# 1. Check for a successful recovery task for Guest-VM-1 (on correct object, no prefix)
$recoveryUrl = "https://$vip/v2/data-protect/recoveries?snapshotEnvironments=kHyperV&status=Succeeded&recoveryActions=RecoverVMs&returnChildTasks=false&fortknoxOnpremRecoveriesOnly=false&pruneObjects=false"
try {
    $recoveryResponse = Invoke-RestMethod -Uri $recoveryUrl -Headers $headers
} catch {
    $errors += "Could not retrieve recovery tasks."
}
$guestVm1Recovery = $null
$recoveryEndTime = $null
$prefixUsed = $null
if ($recoveryResponse.recoveries) {
    foreach ($recovery in $recoveryResponse.recoveries) {
        if ($recovery.hypervParams -and $recovery.hypervParams.objects) {
            foreach ($obj in $recovery.hypervParams.objects) {
                if ($obj.objectInfo -and $obj.objectInfo.name -eq "Guest-VM-1") {
                    $guestVm1Recovery = $recovery
                    $recoveryEndTime = $recovery.endTimeUsecs
                    # Check for prefix under hyperTargetParams.renameRecoveredVmsParams.prefix
                    if ($recovery.hyperTargetParams -and $recovery.hyperTargetParams.renameRecoveredVmsParams) {
                        $prefixUsed = $recovery.hyperTargetParams.renameRecoveredVmsParams.prefix
                    }
                    break
                }
            }
        }
        if ($guestVm1Recovery) { break }
    }
}
if (-not $guestVm1Recovery) {
    $errors += "No successful recovery task found on the correct object (Guest-VM-1). Please perform a recovery on the correct object."
} elseif ($prefixUsed -and $prefixUsed.Trim() -ne "") {
    $errors += "The recovery was performed with a prefix ('$prefixUsed'). Please recover Guest-VM-1 with the original name (no prefix)."
}
# 2. Check Guest-VM-1 is in the protection group and no missing entities
$pgUrl = "https://$vip/v2/data-protect/protection-groups?environments=kHyperV"
try {
    $pgResponse = Invoke-RestMethod -Uri $pgUrl -Headers $headers
} catch {
    $errors += "Could not retrieve Hyper-V protection groups. Please check your cluster and try again."
}
$pg = $pgResponse.protectionGroups | Where-Object { $_.name -eq "VirtualProtection" }
if (-not $pg) {
    $errors += "The protection group 'VirtualProtection' was not found. Please ensure you have created it."
} else {
    # Check missing entities
    if ($pg.missingEntities -and $pg.missingEntities.Count -gt 0) {
        $missingNames = $pg.missingEntities | ForEach-Object { $_.name }
        $errors += "The following VMs are missing from the source: $($missingNames -join ', '). Please refresh the source and ensure all VMs are available."
    }
    # Check Guest-VM-1 is present
    $objectNames = @()
    if ($pg.hypervParams -and $pg.hypervParams.objects) {
        $objectNames = $pg.hypervParams.objects | ForEach-Object { $_.name }
    }
    if (-not ($objectNames -contains "Guest-VM-1")) {
        $errors += "Please make sure Guest-VM-1 is added to the 'VirtualProtection' protection group."
    }
}
# 3. Check for a successful backup run for Guest-VM-1 after recovery
if ($pg -and $guestVm1Recovery) {
    # Find the protection job for this group
    $jobsUrl = "https://$vip/irisservices/api/v1/public/protectionJobs"
    try {
        $jobsResponse = Invoke-RestMethod -Uri $jobsUrl -Headers $headers
    } catch {
        $errors += "Could not retrieve protection jobs."
    }
    $job = $jobsResponse | Where-Object { $_.name -eq "VirtualProtection" -and $_.environment -eq "kHyperV" }
    if (-not $job) {
        $errors += "Could not find a protection job named 'VirtualProtection' for Hyper-V."
    } else {
        $jobId = $job.id
        $runsUrl = "https://$vip/irisservices/api/v1/public/protectionRuns?jobId=$jobId&numRuns=10"
        try {
            $runsResponse = Invoke-RestMethod -Uri $runsUrl -Headers $headers
        } catch {
            $errors += "Could not retrieve recent backup runs for the job."
        }
        if ($runsResponse -and $runsResponse.Count -gt 0) {
            $foundSuccess = $false
            foreach ($run in ($runsResponse | Sort-Object { $_.backupRun.stats.startTimeUsecs } -Descending)) {
                $guestVm1Status = $null
                $runTime = $run.backupRun.stats.startTimeUsecs
                if ($runTime -gt $recoveryEndTime) {
                    if ($run.backupRun.PSObject.Properties.Name -contains "sourceBackupStatus") {
                        foreach ($src in $run.backupRun.sourceBackupStatus) {
                            if ($src.source.name -eq "Guest-VM-1") {
                                $guestVm1Status = $src.status
                                break
                            }
                        }
                    }
                    if ($guestVm1Status -eq "kSuccess") {
                        $foundSuccess = $true
                        break
                    }
                }
            }
            if (-not $foundSuccess) {
                $errors += "You must perform a successful backup run for Guest-VM-1 after restoring and re-adding it."
            }
        } else {
            $errors += "No recent backup runs found for the 'VirtualProtection' job."
        }
    }
}
if ($errors.Count -eq 0) {
    Write-Output "Congratulations! You have successfully recovered Guest-VM-1 (on the correct object, with no prefix), re-added it to the protection group, and performed a successful backup run."
    Write-Output "Correct"
    exit
} else {
    $errors | ForEach-Object { Write-Output $_ }
    Write-Output "Incorrect"
    exit
}
