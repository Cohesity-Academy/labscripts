$in = Connect-CohesityCluster -Server cohesity-a.cohesitylabs.az -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "LOCAL\admin", (ConvertTo-SecureString -AsPlainText "cohesity123" -Force))
$out = get-cohesityphysicalagent
If (($out |?{$_.Name -eq "nfs-server-1.cohesitylabs.az"}).upgradability -eq "kCurrent"){
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
