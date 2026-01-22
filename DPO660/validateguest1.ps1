### usage: ./validateguest1.ps1 -vip mycluster -username myusername -password mypassword
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter(Mandatory = $True)][string]$password
)
# Source the cohesity-api helper code
. ./cohesity-api.ps1
# Authenticate
apiauth -vip $vip -username $username -password $password -quiet
# 1. Check for a successful recovery of Guest-VM-1 to original location, original name
$recoveries = api get -v2 data-protect/recoveries
$goodRecovery = $null
$recoveryEndTime = $null
foreach ($recovery in $recoveries.recoveries) {
    if ($recovery.status -eq "Succeeded" -and $recovery.recoveryAction -eq "RecoverVMs" -and $recovery.hypervParams.objects) {
        foreach ($obj in $recovery.hypervParams.objects) {
            if ($obj.objectInfo.name -eq "Guest-VM-1") {
                $prefixPresent = $false
                $altLocationPresent = $false
                if ($recovery.hypervParams.recoverVmParams.hypervTargetParams.renameRecoveredVmsParams) {
                    $prefixPresent = $true
                }
                if ($recovery.hypervParams.recoverVmParams.hypervTargetParams.recoveryTargetConfig.recoverToNewSource) {
                    $altLocationPresent = $true
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
if (-not $goodRecovery) {
    Write-Host "You must perform a recovery of Guest-VM-1 to the original location with the original name."
    Write-Host "Incorrect"
    exit
}
# 2. Check Guest-VM-1 is back in the protection group and no missing entities
$pgs = api get -v2 data-protect/protection-groups
$pg = $pgs.protectionGroups | Where-Object { $_.name -eq "VirtualProtection" }
$objectNames = @()
if ($pg -and $pg.hypervParams.objects) {
    $objectNames = $pg.hypervParams.objects | ForEach-Object { $_.name }
}
if ($pg) {
    if ($pg.missingEntities -and $pg.missingEntities.Count -gt 0) {
        Write-Host "Refresh the source and add Guest-VM-1 back into the protection group."
        Write-Host "Incorrect"
        exit
    }
    if (-not ($objectNames -contains "Guest-VM-1")) {
        Write-Host "Ensure Guest-VM-1 is added back to the protection group after recovery."
        Write-Host "Incorrect"
        exit
    }
}
# 3. Check for a successful backup run for Guest-VM-1 after recovery
$jobs = api get -v1 public/protectionJobs
$job = $jobs | Where-Object { $_.name -eq "VirtualProtection" -and $_.environment -eq "kHyperV" }
if ($job -and $goodRecovery) {
    $jobId = $job.id
    $runs = api get -v1 public/protectionRuns?jobId=$jobId'&'numRuns=10
    $foundSuccess = $false
    foreach ($run in ($runs | Sort-Object { $_.backupRun.stats.startTimeUsecs } -Descending)) {
        $guestVm1Status = $null
        $runTime = $run.backupRun.stats.startTimeUsecs
        if ($runTime -gt $recoveryEndTime) {
            if ($run.backupRun.sourceBackupStatus) {
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
        Write-Host "Run the protection group and ensure Guest-VM-1 is successfully protected after recovery."
        Write-Host "Incorrect"
        exit
    }
}
Write-Host "Correct"
exit
