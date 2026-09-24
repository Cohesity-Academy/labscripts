#requires -version 5.1

[CmdletBinding()]
param (
    [string]$PrimaryCluster = 'cohesity-a.cohesitylabs.az',
    [string]$Username = 'admin',
    [string]$Domain = 'local',
    [string]$Password = $env:COHESITY_PASSWORD,
    [string]$StorageDomain = 'DefaultStorageDomain',
    [string]$ViewName = 'Jump-Bag',
    [string]$PolicyName = 'Jump-Bag Policy',
    [string]$ProtectionGroupName = 'Jump-Bag Protect',
    [string]$ReplicationTargetName = 'Cohesity-B',
    [string]$ArchiveTargetName = 'Az-Cool-Blob-Archive',
    [string]$AllowClientCidr = '192.168.1.0/24',
    [string]$SeedSourcePath = 'C:\Digital-JumpBag',
    [string]$StartTime = '20:00',
    [string]$TimeZone = 'America/Chicago',
    [ValidateSet('Administrative', 'Compliance')]
    [string]$DataLockMode = 'Administrative',
    [switch]$SkipContentSeed,
    [switch]$SkipInitialRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function New-AllowlistEntry {
    param([Parameter(Mandatory = $true)][string]$Cidr)

    $parts = @($Cidr -split '/')
    $prefixLength = 0
    if ($parts.Count -ne 2 -or -not [int]::TryParse($parts[1], [ref]$prefixLength) -or $prefixLength -lt 0 -or $prefixLength -gt 32) {
        throw "Invalid CIDR value: $Cidr"
    }

    return @{
        ip            = $parts[0]
        netmaskBits   = $prefixLength
        smbAccess     = 'kReadWrite'
        nfsAccess     = 'kReadWrite'
        s3Access      = 'kReadWrite'
        nfsRootSquash = 'kNone'
    }
}

function Get-OneByName {
    param (
        [Parameter(Mandatory = $true)]$Items,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ObjectType
    )

    $matches = @($Items | Where-Object { $_.name -ieq $Name })
    if ($matches.Count -eq 0) {
        throw "$ObjectType '$Name' was not found. Register or create it before running this script."
    }
    if ($matches.Count -gt 1) {
        throw "More than one $ObjectType named '$Name' was found. Use a unique target name."
    }
    return $matches[0]
}

Write-Step 'Loading the Cohesity API helper'
$scriptDirectory = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptDirectory = [System.IO.Path]::GetTempPath()
}
$apiHelper = Join-Path -Path $scriptDirectory -ChildPath 'cohesity-api.ps1'
if (-not (Test-Path $apiHelper)) {
    $helperUrl = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri $helperUrl -OutFile $apiHelper
}
. $apiHelper

if ([string]::IsNullOrWhiteSpace($Password)) {
    $Password = Read-Host 'Cohesity password'
}

Write-Step "Connecting to $PrimaryCluster"
apiauth -vip $PrimaryCluster -username $Username -domain $Domain -passwd $Password -quiet
if (-not $cohesity_api.authorized) {
    throw "Authentication to $PrimaryCluster failed."
}

Write-Host "SMB allowlist entry: $AllowClientCidr"

Write-Step 'Resolving the storage domain and remote targets'
$storageDomainObject = Get-OneByName -Items @(api get viewBoxes) -Name $StorageDomain -ObjectType 'storage domain'
$replicationTarget = Get-OneByName -Items @(api get remoteClusters) -Name $ReplicationTargetName -ObjectType 'remote cluster'
$archiveTarget = Get-OneByName -Items @(api get vaults) -Name $ArchiveTargetName -ObjectType 'external target'

Write-Step "Creating or reusing SMB Backup Target View '$ViewName'"
$view = @((api get -v2 'file-services/views').views | Where-Object { $_.name -ieq $ViewName }) | Select-Object -First 1
if (-not $view) {
    $viewRequest = @{
        name                          = $ViewName
        storageDomainId               = [long]$storageDomainObject.id
        category                      = 'BackupTarget'
        caseInsensitiveNamesEnabled   = $true
        securityMode                  = 'NativeMode'
        isExternallyTriggeredBackupTarget = $false
        enableSmbViewDiscovery        = $true
        overrideGlobalSubnetWhitelist = $true
        subnetWhitelist               = @((New-AllowlistEntry -Cidr $AllowClientCidr))
        protocolAccess                = @(
            @{
                type = 'SMB'
                mode = 'ReadWrite'
            }
        )
        qos                           = @{
            name = 'BackupTargetLow'
        }
        sharePermissions              = @{
            permissions = @(
                @{
                    sid    = 'S-1-1-0'
                    access = 'FullControl'
                    mode   = 'FolderSubFoldersAndFiles'
                    type   = 'Allow'
                }
            )
        }
        smbPermissionsInfo            = @{
            ownerSid    = 'S-1-5-32-544'
            permissions = @(
                @{
                    sid    = 'S-1-1-0'
                    access = 'FullControl'
                    mode   = 'FolderSubFoldersAndFiles'
                    type   = 'Allow'
                }
            )
        }
    }

    $view = api post -v2 'file-services/views' $viewRequest
    if (-not $view) {
        throw "The View '$ViewName' could not be created."
    }
} else {
    Write-Host "View '$ViewName' already exists; updating its IP allowlist."
    $view | Add-Member -MemberType NoteProperty -Name overrideGlobalSubnetWhitelist -Value $true -Force
    $view | Add-Member -MemberType NoteProperty -Name subnetWhitelist -Value @((New-AllowlistEntry -Cidr $AllowClientCidr)) -Force
    $view = api put -v2 "file-services/views/$($view.viewId)" $view
}

$view = @((api get -v2 'file-services/views').views | Where-Object { $_.name -ieq $ViewName }) | Select-Object -First 1
if (-not $view) {
    throw "The View '$ViewName' was not returned after creation."
}

if (-not $SkipContentSeed) {
    Write-Step 'Creating the Digital Jump Bag folder structure'
    $sharePath = "\\$PrimaryCluster\$ViewName"
    Write-Host "Waiting for $sharePath to become available. Press Ctrl+C to stop."
    while (-not (Test-Path -LiteralPath $sharePath)) {
        Start-Sleep -Seconds 5
    }

    $jumpBagRoot = Join-Path $sharePath 'Digital-JumpBag'
    $folders = @(
        '01_Golden_Images_and_ISOs',
        '02_Application_Installers',
        '03_Security_Tools',
        '04_Documentation_and_Playbooks',
        '05_Dial_Tone_Apps'
    )

    $null = New-Item -ItemType Directory -Path $jumpBagRoot -Force
    foreach ($folder in $folders) {
        $folderPath = Join-Path $jumpBagRoot $folder
        $null = New-Item -ItemType Directory -Path $folderPath -Force
    }

    if (Test-Path -LiteralPath $SeedSourcePath -PathType Container) {
        Write-Host "Copying lab content from $SeedSourcePath"
        Copy-Item -Path (Join-Path $SeedSourcePath '*') -Destination $jumpBagRoot -Recurse -Force
    } else {
        Write-Warning "Seed source '$SeedSourcePath' was not found. Creating placeholder files instead."
        foreach ($folder in $folders) {
            $readme = Join-Path (Join-Path $jumpBagRoot $folder) 'README.txt'
            @(
                'River Valley Utilities Digital Jump Bag'
                "Category: $folder"
                'Replace this placeholder with the recovery resources used in the lab.'
            ) | Set-Content -LiteralPath $readme -Encoding UTF8
        }
    }
}

Write-Step "Creating or updating protection policy '$PolicyName'"
$policyRequest = @{
    name         = $PolicyName
    description  = 'River Valley Utilities Digital Jump Bag 3-2-1-1 protection policy'
    backupPolicy = @{
        regular = @{
            incremental = @{
                schedule = @{
                    unit        = 'Days'
                    daySchedule = @{
                        frequency = 1
                    }
                }
            }
            retention   = @{
                unit           = 'Weeks'
                duration       = 2
                dataLockConfig = @{
                    mode     = $DataLockMode
                    unit     = 'Weeks'
                    duration = 2
                }
            }
        }
    }
    remoteTargetPolicy = @{
        replicationTargets = @(
            @{
                schedule           = @{ unit = 'Runs' }
                retention          = @{
                    unit           = 'Months'
                    duration       = 1
                    dataLockConfig = @{
                        mode     = $DataLockMode
                        unit     = 'Days'
                        duration = 14
                    }
                }
                copyOnRunSuccess   = $false
                targetType         = 'RemoteCluster'
                remoteTargetConfig = @{
                    clusterId   = [long]$replicationTarget.clusterId
                    clusterName = $replicationTarget.name
                }
            }
        )
        archivalTargets   = @(
            @{
                schedule         = @{ unit = 'Runs' }
                retention        = @{
                    unit           = 'Months'
                    duration       = 1
                    dataLockConfig = @{
                        mode     = $DataLockMode
                        unit     = 'Days'
                        duration = 14
                    }
                }
                copyOnRunSuccess = $false
                targetId         = [long]$archiveTarget.id
                targetName       = $archiveTarget.name
                targetType       = 'Cloud'
            }
        )
    }
    retryOptions = @{
        retries           = 3
        retryIntervalMins = 5
    }
}

$policy = @((api get -v2 'data-protect/policies').policies | Where-Object { $_.name -ieq $PolicyName }) | Select-Object -First 1
if ($policy) {
    $policyRequest['id'] = $policy.id
    $policy = api put -v2 "data-protect/policies/$($policy.id)" $policyRequest
} else {
    $policy = api post -v2 'data-protect/policies' $policyRequest
}

$policyApiError = $cohesity_api.last_api_error
if ($policyApiError -ne 'OK' -or -not $policy) {
    $policyDebugFile = Join-Path -Path $scriptDirectory -ChildPath 'jumpbag-policy-request.json'
    $policyRequest | ConvertTo-Json -Depth 99 | Set-Content -LiteralPath $policyDebugFile -Encoding UTF8
    throw "Cohesity rejected the protection policy request: $policyApiError Request JSON: $policyDebugFile"
}

$policy = @((api get -v2 'data-protect/policies').policies | Where-Object { $_.name -ieq $PolicyName }) | Select-Object -First 1
if (-not $policy) {
    throw "Cohesity accepted the request but policy '$PolicyName' was not present in the subsequent policy list."
}

Write-Step "Creating or updating protection group '$ProtectionGroupName'"
$timeParts = $StartTime -split ':'
if ($timeParts.Count -ne 2 -or [int]$timeParts[0] -notin 0..23 -or [int]$timeParts[1] -notin 0..59) {
    throw "StartTime '$StartTime' is invalid. Use HH:mm, for example 20:00."
}

$groupRequest = @{
    name             = $ProtectionGroupName
    environment      = 'kView'
    isPaused         = $false
    policyId         = $policy.id
    priority         = 'kMedium'
    qosPolicy        = 'kBackupHDD'
    storageDomainId  = [long]$view.storageDomainId
    description      = 'Protects the River Valley Utilities Digital Jump Bag View'
    startTime        = @{
        hour     = [int]$timeParts[0]
        minute   = [int]$timeParts[1]
        timeZone = $TimeZone
    }
    abortInBlackouts = $false
    alertPolicy      = @{
        backupRunStatus = @('kFailure')
        alertTargets    = @()
    }
    sla              = @(
        @{ backupRunType = 'kFull' },
        @{ backupRunType = 'kIncremental' }
    )
    viewParams       = @{
        indexingPolicy   = @{
            enableIndexing = $true
            includePaths   = @('/')
            excludePaths   = @()
        }
        objects          = @(
            @{ id = [long]$view.viewId }
        )
        replicationParams = @{
            viewNameConfigList = @(
                @{
                    sourceViewId   = [long]$view.viewId
                    useSameViewName = $true
                    viewName        = $ViewName
                }
            )
        }
    }
}

$group = @((api get -v2 'data-protect/protection-groups').protectionGroups | Where-Object { $_.name -ieq $ProtectionGroupName }) | Select-Object -First 1
if ($group) {
    if ($group.environment -ne 'kView') {
        throw "A non-View protection group named '$ProtectionGroupName' already exists."
    }
    $groupRequest['id'] = $group.id
    $group = api put -v2 "data-protect/protection-groups/$($group.id)" $groupRequest
} else {
    $group = api post -v2 'data-protect/protection-groups' $groupRequest
}

$groupApiError = $cohesity_api.last_api_error
if ($groupApiError -ne 'OK' -or -not $group) {
    $groupDebugFile = Join-Path -Path $scriptDirectory -ChildPath 'jumpbag-protection-group-request.json'
    $groupRequest | ConvertTo-Json -Depth 99 | Set-Content -LiteralPath $groupDebugFile -Encoding UTF8
    throw "Cohesity rejected the protection group request: $groupApiError Request JSON: $groupDebugFile"
}

$group = @((api get -v2 'data-protect/protection-groups').protectionGroups | Where-Object { $_.name -ieq $ProtectionGroupName }) | Select-Object -First 1
if (-not $group) {
    throw "The protection group '$ProtectionGroupName' was not returned after creation or update."
}

if (-not $SkipInitialRun) {
    Write-Step 'Starting the initial protection run'
    $runRequest = @{
        runType = 'kRegular'
    }
    $null = api post -v2 "data-protect/protection-groups/$($group.id)/runs" $runRequest
}

Write-Host "`nJump Bag lab setup is complete." -ForegroundColor Green
Write-Host "View:              $ViewName"
Write-Host "SMB path:          \\$PrimaryCluster\$ViewName"
Write-Host "Policy:            $PolicyName"
Write-Host "Protection group:  $ProtectionGroupName"
Write-Host "Replication:       $ReplicationTargetName"
Write-Host "Archive:           $ArchiveTargetName"
if (-not $SkipInitialRun) {
    Write-Host 'Initial run:        Requested'
}
