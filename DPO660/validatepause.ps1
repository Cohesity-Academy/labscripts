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
# 1. Get the policy ID for "Critical_Prod"
$policyUrl = "https://$vip/v2/data-protect/policies?policyNames=Critical_Prod&types=Regular"
try {
    $policyResponse = Invoke-RestMethod -Uri $policyUrl -Headers $headers
} catch {
    Write-Output "Policy query failed."
    Write-Output "Incorrect"
    exit
}
$policyId = $null
if ($policyResponse.policies) {
    foreach ($policy in $policyResponse.policies) {
        if ($policy.name -eq "Critical_Prod" -and $policy.id) {
            $policyId = $policy.id -replace '\s',''
            break
        }
    }
}
if (-not $policyId) {
    Write-Output "Please verify that the 'Critical_Prod' policy exists."
    Write-Output "Incorrect"
    exit
}
# 2. Find all physical block protection groups
$pgUrl = "https://$vip/v2/data-protect/protection-groups?environments=kPhysical"
try {
    $pgResponse = Invoke-RestMethod -Uri $pgUrl -Headers $headers
} catch {
    Write-Output "Protection group query failed."
    Write-Output "Incorrect"
    exit
}
# 3. Filter for only Physical Block (Volume) groups
$blockGroups = $pgResponse.protectionGroups | Where-Object {
    ($_.environment -eq "Physical" -or $_.environment -eq "kPhysical") -and
    $_.physicalParams -and
    $_.physicalParams.protectionType -eq "kVolume"
}
if (-not $blockGroups -or $blockGroups.Count -eq 0) {
    Write-Output "Please verify that a Physical Block (Volume) Protection Group exists."
    Write-Output "Incorrect"
    exit
}
$foundCorrect = $false
$allErrors = @()
foreach ($pg in $blockGroups) {
    $errors = @()
    if ($pg.name -ne "WindowsBlockProtection") {
        $errors += "Please verify the name of your Windows Physical Block Protection Group."
    }
    if (($pg.policyId -replace '\s','') -ne $policyId) {
        $errors += "Please verify the policy assigned to your Windows Physical Block Protection Group."
    }
    if (-not $pg.startTime -or $pg.startTime.hour -ne 22 -or $pg.startTime.minute -ne 0) {
        $errors += "Please verify the start time of your Windows Physical Block Protection Group."
    }
    if ($pg.isPaused -ne $true) {
        $errors += "Please verify that your Windows Physical Block Protection Group is paused."
    }
    if ($errors.Count -eq 0) {
        Write-Output "Correct"
        exit
    } else {
        $allErrors += $errors
    }
}
$allErrors | Sort-Object -Unique | ForEach-Object { Write-Output $_ }
Write-Output "Incorrect"
