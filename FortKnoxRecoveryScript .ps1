<# 
FortKnox Recovery Script 
#> 

$timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm" 

# Define variables: these variables are required and will be unique to your environment 
    $heliosUsername = "username" 
    $heliosApiKey = "apikey" 
    $clusterName = "cluster01" 
    $vmName = "vm01" 
    $vmHistoricalIndex = "1" 
    $recoveryName = "FortKnox-Recovery-$timestamp" 
    $prefix = "Vault" 
    $vCenterName = "vcenter01" 
    $ResourcePoolName = "Quarantine" 
    $datastoreName = "Isolated" 
    $vmFolderName = "Isolated" 
    $networkPortGroupName = "Isolated" 
    $loggingLocation = "C:\Logs\FortKnox_Recovery_$timestamp.log" 

    #Quorum approval account 
    $heliosUsername2 = "quorumapprover1@company.com" 
    $heliosApiKey2 = "apikey" 

###BEGIN SCRIPT### 

# This script will retrieve an object from a snapshot in FortKnox and recover to a new location 

# Define Helios API root URLs 
    $heliosApiRootUrl = "https://helios.cohesity.com" 
    $heliosApiRootUrlv2 = "https://helios.cohesity.com/v2" 

# Import logging module 
Import-Module -Name Microsoft.PowerShell.Utility 

# Get current date and time 
$startTime = Get-Date 

# Check if log file exists 
if (Test-Path $loggingLocation) { 
    # Append to existing log file 
    $Logfile = Get-Item $loggingLocation 
} else { 
    # Create new log file 
    $Logfile = New-Item -ItemType File -Path $loggingLocation -Force 
} 

# Define logging function 
function LogWrite 
{ 
    Param ([string]$logstring) 

    # Get current date and time 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 

    Add-content $Logfile -value "$timestamp $logstring" 
} 

# Log start time 
LogWrite "Script started at $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" 
LogWrite "   " 

# Log variable values 
LogWrite "heliosUsername set to $heliosUsername" 
LogWrite "heliosApiKey set to $heliosApiKey" 
LogWrite "clusterName set to $clusterName" 
LogWrite "vmName set to $vmName" 
LogWrite "secondToLastSnapshotIndex set to $secondToLastSnapshotIndex" 
LogWrite "recoveryName set to $recoveryName" 
LogWrite "prefix set to $prefix" 
LogWrite "vCenterName set to $vCenterName" 
LogWrite "ResourcePoolName set to $ResourcePoolName" 
LogWrite "datastoreName set to $datastoreName" 
LogWrite "vmFolderName set to $vmFolderName" 
LogWrite "networkPortGroupName set to $networkPortGroupName" 
LogWrite "loggingLocation set to $loggingLocation" 
LogWrite "   " 

#Gather VM and vCenter Information needed to build the recovery task payload 
LogWrite "Gathering VM and vCenter Information needed to build the recovery task payload..." 
Write-Output "Gathering VM and vCenter Information needed to build the recovery task payload..." 

    # Get the cluster ID and registration information from the cluster name 
    LogWrite "Getting cluster ID and registration information from the cluster name..." 
    Write-Output "Getting cluster ID and registration information from the cluster name..." 
        ### Create authorized header for FortKnox Demo Helios user 
        $authorizedHeaderHelios = @{ 
            "Username" = $heliosUsername 
            "apiKey" = $heliosApiKey 
            "accessClusterId" = $clusterID 
            "accept" = "application/json" 
            "Content-type" = "application/json" 
        } 

        try { 
            # Make the API call to get the cluster ID 
            $response = Invoke-RestMethod -Method Get -Uri "$heliosApiRootUrl/mcm/clusters/connectionStatus" -Headers $authorizedHeaderHelios -SkipCertificateCheck 

            # Find the cluster ID by cluster name in the response 
            $clusterID = ($response | Where-Object { $_.name -eq $clusterName }).clusterId 
            LogWrite "clusterID set to $clusterID" 
            Write-Output "clusterID set to $clusterID" 
            } 
        catch { 
            Write-Error "Error occurred while getting cluster ID: $_" 
            LogWrite "Error occurred while getting cluster ID: $_"         
        } 

    # Gather information about registered sources, this information will be used for recovering to an alternate location 
    LogWrite "Gathering information about registered sources, this information will be used for recovering to an alternate location..." 
    Write-Output "Gathering information about registered sources, this information will be used for recovering to an alternate location..." 
        # Define the API call headers 
        $authorizedHeaderHelios = @{ 
            "Username" = $heliosUsername 
            "apiKey" = $heliosApiKey 
            "accessClusterId" = $clusterID 
            "accept" = "application/json" 
            "Content-type" = "application/json" 
        } 

        try { 
            # Make the API call to get the Vcenter ID 
            $response = Invoke-RestMethod -Method Get -Uri "$heliosApiRootUrl/irisservices/api/v1/public/protectionSources?useCachedData=false&includeVMFolders=true&includeSystemVApps=true&includeEntityPermissionInfo=true&includeTypes=kResourcePool&includedatastoreInfo&environment=kVMware&allUnderHierarchy=true" -Headers $authorizedHeaderHelios -SkipCertificateCheck 
  
            # Get the vCenter source by name in the response 
            $vCenterSource = ($response | Where-Object { $_.protectionSource.name -eq $vCenterName }).protectionSource 
  
            # Get the vCenter ID from the vCenter source 
            $vCenterID = $vCenterSource.id 
            LogWrite "vCenterID set to $vCenterID" 
            Write-Output "vCenterID set to $vCenterID" 
        }    
        catch { 
            Write-Error "Error occurred while getting vCenter Source ID: $_" 
            LogWrite "Error occurred while getting vCenter Source ID: $_" 
        } 
  
        # Get the resource pool ID from the vCenter source 
        LogWrite "Getting resource pool ID from the vCenter source..." 
        Write-Output "Getting resource pool ID from the vCenter source..." 
        try { 
            # Make the API call to get Vcenter resource pool ID 
            $response = Invoke-RestMethod -Method Get -Uri "$heliosApiRootUrl/irisservices/api/v1/resourcePools?vCenterId=$vcenterID" -Headers $authorizedHeaderHelios -SkipCertificateCheck 
            $resourcePoolId = $response.resourcePool | Where-Object { $_.displayName -eq "$resourcePoolName" } | Select-Object -ExpandProperty id 
            LogWrite "resourcePoolId set to $resourcePoolId" 
            Write-Output "resourcePoolId set to $resourcePoolId" 
        } 
        catch { 
            Write-Error "Error occurred while getting resource pool ID: $_" 
            LogWrite "Error occurred while getting resource pool ID: $_" 
        } 
  
        # Get the datastores from the vCenter source and find Datastore ID 
        LogWrite "Getting datastores from the vCenter source and finding Datastore ID..." 
        Write-Output "Getting datastores from the vCenter source and finding Datastore ID..." 
        try { 
            #Get the datastores from the vCenter source 
            $response = Invoke-RestMethod -Method Get -Uri "$heliosApiRootUrl/irisservices/api/v1/datastores?resourcePoolId=$resourcePoolId&vCenterId=$vcenterId" -Headers $authorizedHeaderHelios -SkipCertificateCheck 
            #Find the datastore ID by datastore name in the response 
            $datastoreId = $response | Where-Object { $_.displayName -eq "$datastoreName" } | Where-Object { $_.parentId -eq "$vCenterID" } | Select-Object -ExpandProperty id 
            LogWrite "datastoreId set to $datastoreId" 
            Write-Output "datastoreId set to $datastoreId" 
        } 
        catch { 
            Write-Error "Error occurred while getting datastore ID: $_" 
            LogWrite "Error occurred while getting datastore ID: $_" 
        } 
         
        # Get the VM folder ID from the vCenter source 
        LogWrite "Getting VM folder ID from the vCenter source..." 
        Write-Output "Getting VM folder ID from the vCenter source..." 
        try { 
            # Make the API call to get VM folders on vCenter 
            $response = Invoke-RestMethod -Method Get -Uri "$heliosApiRootUrl/irisservices/api/v1/vmwareFolders?vCenterId=$vcenterID&resourcePoolId=$resourcePoolId" -Headers $authorizedHeaderHelios -SkipCertificateCheck 
            # Find the VM folder ID by VM folder name in the response 
            $vmFolderId = $response.vmFolders | Where-Object { $_.displayName -eq "$vmFolderName" } | Select-Object -ExpandProperty id 
            LogWrite "vmFolderId set to $vmFolderId" 
            Write-Output "vmFolderId set to $vmFolderId" 
        } 
        catch { 
            Write-Error "Error occurred while getting VM folder ID: $_" 
            LogWrite "Error occurred while getting VM folder ID: $_" 
        } 
  
        # Get the networks from the vCenter source 
        LogWrite "Getting networks from the vCenter source..." 
        Write-Output "Getting networks from the vCenter source..." 
        try { 
            # Get the networks from the vCenter source and match to variable name 
            $response = Invoke-RestMethod -Method Get -Uri "$heliosApiRootUrl/irisservices/api/v1/networkEntities?vCenterId=$vcenterID&resourcePoolId=$resourcePoolId" -Headers $authorizedHeaderHelios -SkipCertificateCheck 
            # Find the network ID by network name in the response 
            $networkPortGroupId = $response | Where-Object { $_.displayname -eq "$networkPortGroupName" } | Select-Object -ExpandProperty id 
            LogWrite "networkPortGroupId set to $networkPortGroupId" 
            Write-Output "networkPortGroupId set to $networkPortGroupId" 
        } 
        catch { 
            Write-Error "Error occurred while getting network port group name: $_" 
            LogWrite "Error occurred while getting network port group name: $_" 
        } 
  
#Gather Cohesity Snapshot information needed to build the recovery task payload 
  
  
LogWrite "Gathering Cohesity Snapshot information needed to build the recovery task payload..." 
Write-Output "Gathering Cohesity Snapshot information needed to build the recovery task payload..." 
    ### Create authorized header for FortKnox Demo Helios user 
    $authorizedHeaderHelios = @{ 
        "Username" = $heliosUsername 
        "apiKey" = $heliosApiKey 
        "accessClusterId" = $clusterID 
        "accept" = "application/json" 
        "Content-type" = "application/json" 
    } 
  
    #Get the list of snapshots for the VM 
    LogWrite "Getting the list of snapshots for the VM..." 
    Write-Output "Getting the list of snapshots for the VM..." 
    try { 
        # Get the Cohesity Protection Group for the VM 
        LogWrite "Getting the Cohesity Protection Group for the VM..." 
        Write-Output "Getting the Cohesity Protection Group for the VM..." 
        $response = Invoke-RestMethod -Method Get -Uri "$heliosApiRootUrlV2/data-protect/search/protected-objects?sourceIds=1&snapshotActions=RecoverVMs,RecoverVApps&searchString=$vmName" -Headers $authorizedHeaderHelios -SkipCertificateCheck 
        $vmObjectId = $response.objects | Where-Object { $_.name -eq $vmName } | Select-Object -ExpandProperty id 
        LogWrite "vmObjectId set to $vmObjectId" 
        Write-Output "vmObjectId set to $vmObjectId" 
  
        # Get the snapshot ID for the VM for selected snap, "last known good" 
        LogWrite "Get the snapshot ID for the VM..." 
        Write-Output "Get the snapshot ID for the VM..." 
        $response = Invoke-RestMethod -Method Get -Uri "$heliosApiRootUrlV2/data-protect/objects/$vmObjectId/snapshots" -Headers $authorizedHeaderHelios -SkipCertificateCheck 
        $snapshotId = $response.snapshots | Where-Object { $_.ownershipContext -eq "FortKnox" } | Sort-Object -Property snapshotTimestamp -Descending | Select-Object -Skip $vmHistoricalIndex -First 1 -ExpandProperty id 
        LogWrite "Vaulted snapshotId set to $snapshotId" 
        Write-Output "Vaulted snapshotId set to $snapshotId" 
  
    } 
    catch { 
        Write-Error "Error occurred while getting vaulted snapshot ID: $_" 
        LogWrite "Error occurred while getting vaulted snapshot ID: $_" 
    } 
  
#Build the recovery task payload and submit the recovery task for quorum approval 
LogWrite "Building the recovery task payload and submitting the recovery task for quorum approval..." 
Write-Output "Building the recovery task payload and submitting the recovery task for quorum approval..." 
    #Build the payload 
        # Build the recovery task payload 
        $payload = @{ 
            name = "$recoveryName" 
            snapshotEnvironment = "kVMware" 
            vmwareParams = @{ 
                objects = @( 
                    @{ 
                        snapshotId = $snapshotId 
                    } 
                ) 
                recoveryAction = "RecoverVMs" 
                recoverVmParams = @{ 
                    targetEnvironment = "kVMware" 
                    recoverProtectionGroupRunsParams = @() 
                    vmwareTargetParams = @{ 
                        recoveryTargetConfig = @{ 
                            recoverToNewSource = $true 
                            newSourceConfig = @{ 
                                sourceType = "kVCenter" 
                                vCenterParams = @{ 
                                    source = @{ 
                                        id = $vcenterID 
                                    } 
                                    networkConfig = @{ 
                                        detachNetwork = $false 
                                        newNetworkConfig = @{ 
                                            networkPortGroup = @{ 
                                                id = $networkPortGroupId 
                                            } 
                                            disableNetwork = $true 
                                            preserveMacAddress = $false 
                                        } 
                                    } 
                                    datastores = @( 
                                        @{ 
                                            type = 1 
                                            vmwareEntity = @{ 
                                                type = 6 
                                                moref = @{ 
                                                    item = "datastore-$datastoreID" 
                                                    type = "Datastore" 
                                                } 
                                                name = $datastoreName 
                                                datastoreInfo = @{ 
                                                    capacity = $datastoreCapacity 
                                                    freeSpace = $datastoreFreeSpace 
                                                    datacenterName = $datacenterName 
                                                } 
                                            } 
                                            id = $datastoreID 
                                            parentId = 1 
                                            displayName = $datastoreName 
                                        } 
                                    ) 
                                    resourcePool = @{ 
                                        id = $resourcePoolId 
                                    } 
                                    vmFolder = @{ 
                                        id = $vmFolderId 
                                    } 
                                } 
                            } 
                        } 
                        renameRecoveredVAppsParams = $null 
                        renameRecoveredVmsParams = @{ 
                            prefix = "$prefix-" 
                            suffix = $null 
                        } 
                        recoveryProcessType = "InstantRecovery" 
                        powerOnVms = $false 
                        continueOnError = $false 
                        isMultiStageRestore = $false 
                    } 
                } 
            } 
        } 
     
    try { 
        ### Create authorized header for FortKnox Demo Helios user 
        $authorizedHeaderHelios = @{ 
            "Username" = $heliosUsername 
            "apiKey" = $heliosApiKey 
            "accessClusterId" = $clusterID 
            "accept" = "application/json" 
            "Content-type" = "application/json" 
        } 
  
        # Submit the recovery task for quorum approval 
        LogWrite "Submitting the recovery task for quorum approval..." 
        Write-Output "Submitting the recovery task for quorum approval..." 
        $recoveryResponse = Invoke-RestMethod -Method Post -Uri "$heliosApiRootUrlv2/data-protect/recoveries" -Headers $authorizedHeaderHelios -Body ($payload | ConvertTo-Json -Depth 100) -SkipCertificateCheck 
        $quorumResponseId = $recoveryResponse.quorumResponse.id 
        LogWrite "Recovery task submitted successfully. Quorum Task ID: $($recoveryResponse.quorumResponse.id)" 
        Write-Output "Recovery task submitted successfully. Quorum Task ID: $($recoveryResponse.quorumResponse.id)" 
        Start-Sleep -seconds 15 
} 
catch { 
    Write-Error "Error occurred while submitting the recovery task payload: $_" 
    LogWrite "Error occurred while submitting the recovery task payload: $_" 
} 
  
#Approve the quorum task for recovery 
LogWrite "Approving the quorum task for recovery..." 
Write-Output "Approving the quorum task for recovery..." 
    #Build header for quorum approval account 
    Write-Output "Connecting to Helios as $heliosUsername2  ..." 
    LogWrite "Connecting to Helios as $heliosUsername2  ..." 
    $authorizedHeaderHelios2 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
    $authorizedHeaderHelios2.Add("Username", $heliosUsername2) 
    $authorizedHeaderHelios2.Add("apiKey", $heliosApiKey2) 
    $authorizedHeaderHelios2.Add("accept", "application/json") 
    $authorizedHeaderHelios2.Add("Content-type", "application/json") 
  
    #Approve quorum request 
    try { 
            # Approve the quorum task for recovery 
            LogWrite "Approving the quorum task for recovery..." 
            Write-Output "Approving the quorum task for recovery..." 
            $payload = @{"isApproved"=$true; "remark"="Recovery request approved."} | ConvertTo-Json 
            $response = Invoke-RestMethod -Method POST -Uri "$heliosApiRootUrlv2/mcm/quorum/received-quorum-requests/$quorumResponseId" -Headers $authorizedHeaderHelios2 -Body $payload -SkipCertificateCheck 
            LogWrite "Quorum task approved successfully." 
            Write-Output "Quorum task approved successfully." 
            Start-Sleep -seconds 15 
    } 
    catch { 
        Write-Error "Error occurred while approving the quorum task for recovery: $_" 
        LogWrite "Error occurred while approving the quorum task for recovery: $_" 
    } 
     
  
  
#Check the status of the recovery task 
LogWrite "Checking the status of the recovery task..." 
Write-Output "Checking the status of the recovery task..." 
    ### Create authorized header for FortKnox Demo Helios user 
    $authorizedHeaderHelios = @{ 
        "Username" = $heliosUsername 
        "apiKey" = $heliosApiKey 
        "accessClusterId" = $clusterID 
        "accept" = "application/json" 
        "Content-type" = "application/json" 
    } 
  
    ### Verify vault VM recovery is complete. 
    ## Poll Helios Recoveries until recovery is complete 
    do { 
        Write-Output "Waiting for recovery of "$prefix"-"$VMname" to complete ..." 
        LogWrite "Waiting for recovery of "$prefix"-"$VMname" to complete ..." 
        Start-Sleep 15 
  
        ## Get current time in usecs, and 120 minutes earlier in usecs 
        $fromEpochTime = [Math]::Floor([decimal](Get-Date((Get-Date).AddMinutes(-120)).ToUniversalTime()-uformat "%s")) 
        $fromUsecs = $fromEpochTime * 1000000 
        $toEpochTime = [Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime()-uformat "%s")) 
        $toUsecs = $toEpochTime * 1000000 
        $response = Invoke-RestMethod -Method GET -Uri "$heliosApiRootUrlv2/mcm/data-protect/recoveries?toTimeUsecs=$toUsecs&isRpaas=true&fromTimeUsecs=$fromUsecs" -Headers $authorizedHeaderHelios -SkipCertificateCheck 
        $recoveryStatus = $response | Where-Object { $_.name -eq $recoveryName -and $_.clusterId -eq $clusterID } | Select-Object -ExpandProperty status 
        write-output "RECOVERY NAME: $recoveryName" 
        LogWrite "RECOVERY NAME: $recoveryName" 
        write-output "RECOVERY STATUS: $recoveryStatus"  
        LogWrite "RECOVERY STATUS: $recoveryStatus" 
    } while ($recoveryStatus -eq "Running") 
  
    if ($recoveryStatus -eq "Succeeded") { 
        write-output "Recovery of "$prefix"-"$VMname" to $vCenterName has Completed." 
        LogWrite "Recovery of "$prefix"-"$VMname" to $vCenterName has Completed." 
    } else { 
        write-Output "Recovery of "$prefix"-"$VMname" to $vCenterName has ." 
        LogWrite "Recovery of "$prefix"-"$VMname" to $vCenterName has failed." 
    } 
     
# Get current date and time 
$endTime = Get-Date 
  
# Log end time 
LogWrite "Script ended at $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" 
  
# Calculate and log script duration 
$duration = New-TimeSpan -Start $startTime -End $endTime 
LogWrite "Script duration: $($duration.ToString())" 
LogWrite "SCRIPT COMPLETE" 
LogWrite "   " 
LogWrite "   " 
LogWrite "   " 
  
#End of Script 
