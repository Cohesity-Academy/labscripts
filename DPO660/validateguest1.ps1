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
    Write-Output "Authentication failed."
    Write-Output "Incorrect"
    exit
}
$headers = @{
    "accept" = "application/json"
    "authorization" = "Bearer $token"
}

# 1. Check for a successful recovery of Guest-VM-1 to original location, original name
$recoveryUrl = "https://$vip/v2/data-protect/recoveries"
try {
    $recoveries = Invoke-RestMethod -Uri $recoveryUrl -Headers $headers
} catch {
    Write-Output "Could not retrieve recovery tasks."
    Write-Output "Incorrect"
    exit
}
$goodRecovery = $null
$recoveryEndTime = $null

if ($recoveries.recoveries) {
    foreach ($recovery in $recoveries.recoveries) {
        if ($recovery.status -eq "Succeeded" -and $recovery.recoveryAction -eq "RecoverVMs" -and $recovery.hypervParams.objects) {
            foreach ($obj in $recovery.hypervParams.objects) {
                if ($obj.objectInfo.name -eq "Guest-VM-1") {
                    $prefixPresent = $false
                    $altLocationPresent = $false

                    $rvmp = $recovery.hypervParams.recoverVmParams
                    $htp = $null
                    if ($rvmp) { $htp = $rvmp.hypervTargetParams }
                    if ($htp) {
                        if ($htp.PSObject.Properties.Name -contains "renameRecoveredVmsParams" -and $htp.renameRecoveredVmsParams) {
                            $prefixPresent = $true
                        }
                        if ($htp.PSObject.Properties.Name -contains "recoveryTargetConfig" -and $htp.recoveryTargetConfig) {
                            if ($htp.recoveryTargetConfig.PSObject.Properties.Name -contains "recoverToNewSource" -and $htp.recoveryTargetConfig.recoverToNewSource) {
                                $altLocationPresent = $true
                            }
                        }
                    }

                    if (-not $prefixPresent -and -not $altLocationPresent) {
                        $goodRecovery = $recovery
                        $recoveryEndTime = $recovery.endTimeUsecs
                        break
                    }
                }
            }
        }
        if ($goodRecovery) { break }
    }
}
if (-not $goodRecovery) {
    Write-Output "You must perform a recovery of Guest-VM-1 to the original location with the original name."
    Write-Output "Incorrect"
    exit
}

# 2. Check Guest-VM-1 is back in the protection group and no missing entities
$pgUrl = "https://$vip/v2/data-protect/protection-groups"
try {
    $pgs = Invoke-RestMethod -Uri $pgUrl -Headers $headers
} catch {
    Write-Output "Could not retrieve protection groups."
    Write-Output "Incorrect"
    exit
}
$pg = $null
if ($pgs.protectionGroups) {
    $pg = $pgs.protectionGroups | Where-Object { $_.name -eq "VirtualProtection" }
}
$objectNames = @()
if ($pg -and $pg.hypervParams.objects) {
    $objectNames = $pg.hypervParams.objects | ForEach-Object { $_.name }
}
if (-not $pg) {
    Write-Output "Protection group 'VirtualProtection' not found."
    Write-Output "Incorrect"
    exit
}
if ($pg.missingEntities -and $pg.missingEntities.Count -gt 0) {
    Write-Output "Refresh the source and add Guest-VM-1 back into the protection group."
    Write-Output "Incorrect"
    exit
}
if (-not ($objectNames -contains "Guest-VM-1")) {
    Write-Output "Ensure Guest-VM-1 is added back to the protection group after recovery."
    Write-Output "Incorrect"
    exit
}

# 3. Check the last run for ONLY Guest-VM-1 and it is successful
$pgId = $pg.id
$runsUrl = "https://$vip/v2/data-protect/protection-groups/$pgId/runs?includeObjectDetails=true&numRuns=1"
try {
    $runsResponse = Invoke-RestMethod -Uri $runsUrl -Headers $headers
} catch {
    Write-Output "Could not retrieve runs for 'VirtualProtection'."
    Write-Output "Incorrect"
    exit
}

if (-not $runsResponse.runs -or $runsResponse.runs.Count -eq 0) {
    Write-Output "No runs found for 'VirtualProtection'."
    Write-Output "Incorrect"
    exit
}

$lastRun = $runsResponse.runs[0]

if (-not $lastRun.objects -or $lastRun.objects.Count -eq 0) {
    Write-Output "No objects found in the last run."
    Write-Output "Incorrect"
    exit
}

if ($lastRun.objects.Count -ne 1) {
    Write-Output "Only Guest-VM-1 should be protected in the last run."
    Write-Output "Incorrect"
    exit
}

$guestVm1 = $lastRun.objects[0]
if ($guestVm1.object.name -ne "Guest-VM-1") {
    Write-Output "Only Guest-VM-1 should be protected in the last run."
    Write-Output "Incorrect"
    exit
}

$status = $guestVm1.localSnapshotInfo.snapshotInfo.status
if ($status -ne "kSuccess" -and $status -ne "kSuccessful") {
    Write-Output "Guest-VM-1 was not successfully protected in the last run."
    Write-Output "Incorrect"
    exit
}

Write-Output "Correct"
exit
