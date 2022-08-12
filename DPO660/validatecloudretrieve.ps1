$connect = Connect-CohesityCluster -Server cohesity-b.cohesitylabs.az -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "LOCAL\admin", (ConvertTo-SecureString -AsPlainText "cohesity123" -Force))
$out = Get-CohesityProtectionJob

If (($out |?{$_.Name -eq "HyperVCloudProtection"}).Name -eq "HyperVCloudProtection"){
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
