$connect = Connect-CohesityCluster -Server cohesity-a.cohesitylabs.az -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "LOCAL\admin", (ConvertTo-SecureString -AsPlainText "cohesity123" -Force))
$out = Get-CohesityProtectionJob

If (($out |?{$_.Name -eq "WindowsProtection"}).Name -eq "WindowsProtection" -and ($out |?{$_.Name -eq "Frequent"}).Name -eq "Frequent" -and ($out |?{$_.Name -eq "HyperVCloudProtection"}).Name -eq "HyperVCloudProtection" -and ($out |?{$_.Name -eq "NasProtection"}).Name -eq "NasProtection" -and ($out |?{$_.Name -eq "HyperVReplicationProtection"}).Name -eq "HyperVReplicationProtection"){
Write-Host "Correct"
}
Else {Write-Host "Incorrect"}
