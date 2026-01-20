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
# 1. Get all protection groups
$pgUrl = "https://$vip/v2/data-protect/protection-groups?environments=kHyperV"
try {
    $pgResponse = Invoke-RestMethod -Uri $pgUrl -Headers $headers
} catch {
    Write-Output "Could not retrieve Hyper-V protection groups. Please check your cluster and try again."
    Write-Output "Incorrect"
    exit
}
$pg = $pgResponse.protectionGroups | Where-Object { $_.name -eq "VirtualProtection" }
if (-not $pg) {
    Write-Output "The protection group 'VirtualProtection' was not found. Please ensure you have created it."
    Write-Output "Incorrect"
    exit
}
$errors = @()
# 1. Check missingEntities
if ($pg.missingEntities -and $pg.missingEntities.Count -gt 0) {
    $missingNames = $pg.missingEntities | ForEach-Object { $_.name }
    $errors += "The following VMs are missing from the source: $($missingNames -join ', '). Please refresh the source and ensure all VMs are available."
}
# 2. Check Guest-VM-1 is included
$objectNames = @()
if ($pg.hypervParams -and $pg.hypervParams.objects) {
    $objectNames = $pg.hypervParams.objects | ForEach-Object { $_.name }
}
if (-not ($objectNames -contains "Guest-VM-1")) {
    $errors += "Please make sure Guest-VM-1 is added to the 'VirtualProtection' protection group."
}
# 3. Find the protection job for this group
$jobsUrl = "https://$vip/irisservices/api/v1/public/protectionJobs"
try {
    $jobsResponse = Invoke-RestMethod -Uri $jobsUrl -Headers $headers
} catch {
    $errors += "Could not retrieve protection jobs."
}
$job = $jobsResponse | Where-Object { $_.name -eq "VirtualProtection" -and $_.environment -eq "kHyperV" }
if (-not $job) {
    $errors += "Could not find a protection job named 'VirtualProtection' for Hyper-V."
}
# 4. Get the last run for this job and check status
if ($job) {
    $jobId = $job.id
    $runsUrl = "https://$vip/irisservices/api/v1/public/protectionRuns?jobId=$jobId&numRuns=1"
    try {
        $runsResponse = Invoke-RestMethod -Uri $runsUrl -Headers $headers
    } catch {
        $errors += "Could not retrieve recent backup runs for the job."
    }
    if ($runsResponse -and $runsResponse.Count -gt 0) {
        $lastRun = $runsResponse[0]
        $status = $lastRun.backupRun.status
        if ($status -ne "kSuccess" -and $status -ne "Succeeded") {
            $errors += "The most recent backup run did not complete successfully (status: $status). Please resolve any issues and try again."
        } else {
            # 5. Check that Guest-VM-1 was included in the last run
            $guestVm1Included = $false
            if ($lastRun.backupRun.PSObject.Properties.Name -contains "sourceBackupStatus") {
                foreach ($src in $lastRun.backupRun.sourceBackupStatus) {
                    if ($src.source.name -eq "Guest-VM-1" -and $src.status -eq "kSuccess") {
                        $guestVm1Included = $true
                        break
                    }
                }
            }
            if (-not $guestVm1Included) {
                $errors += "Guest-VM-1 was not included in the most recent successful backup run."
            }
        }
    } else {
        $errors += "No recent backup runs found for the 'VirtualProtection' job."
    }
}
if ($errors.Count -eq 0) {
    Write-Output "Congratulations! There are no missing entities, Guest-VM-1 is included, and the last backup run was successful."
    Write-Output "Correct"
    exit
} else {
    $errors | ForEach-Object { Write-Output $_ }
    Write-Output "Incorrect"
    exit
}
