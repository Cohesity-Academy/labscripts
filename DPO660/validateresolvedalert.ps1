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
# Get Bearer token
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
    Write-Output "Incorrect"
    exit
}
# Use Bearer token for API call
$headers = @{
    "accept" = "application/json"
    "authorization" = "Bearer $token"
}
# Build the URL with propertyKey/propertyValue filters
$url = "https://$vip/v2/alerts?alertCategories=kBackupRestore" +
       "&alertStates=kResolved" +
       "&alertSeverities=kCritical" +
       "&alertTypeBuckets=kDataService" +
       "&alertName=ProtectionGroupFailed" +
       "&propertyKey=job_name&propertyValue=VirtualProtection" +
       "&propertyKey=failed_object&propertyValue=Guest-VM1"
try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers
} catch {
    Write-Output "Incorrect"
    exit
}
# If the response is an object with an 'alerts' property, use that
if ($response.PSObject.Properties.Name -contains "alerts") {
    $alerts = $response.alerts
} else {
    $alerts = $response
}
if ($alerts -and $alerts.Count -gt 0) {
    Write-Output "Correct"
} else {
    Write-Output "Incorrect"
}
