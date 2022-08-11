### usage: ./deployWindowsAgent.ps1 -vip bseltzve01 -username admin -password password -serverList ./servers.txt [ -installAgent ] [ -register ]
### provide a list of servers in a text file
### specify any of -installAgent -register -registerSQL -serviceAccount -storePassword

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #Cohesity cluster to connect to
    [Parameter(Mandatory = $True)][string]$username, #Cohesity username
    [Parameter()][string]$password,
    [Parameter()][string]$domain = 'local', #Cohesity user domain name
    [Parameter()][string]$serverList, #Servers to add as physical source
    [Parameter()][string]$server,
    [Parameter()][switch]$storePassword,
    [Parameter()][switch]$installAgent,
    [Parameter()][switch]$register,
    [Parameter()][string]$serviceAccount = $null
)

if($serverList){
    $servers = get-content $serverList
    }elseif($server) {
        $servers = @($server)
    }else{
        Write-Warning "No Servers Specified"
        exit
    }
    
### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### function to set service account
Function Set-ServiceAcctCreds([string]$strCompName,[string]$strServiceName,[string]$newAcct,[string]$newPass){
    $filter = 'Name=' + "'" + $strServiceName + "'" + ''
    $service = Get-WMIObject -ComputerName $strCompName -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
    $service.Change($null,$null,$null,$null,$null,$null,$newAcct,$newPass)
    $service.StopService()
    while ($service.Started){
      Start-Sleep 2
      $service = Get-WMIObject -ComputerName $strCompName -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
    }
    $service.StartService()
}

### authenticate
apiauth -vip $vip -username $username -password $password -domain $domain

### get protection sources
$sources = api get protectionSources/registrationInfo

### download agent installer to local host
if ($installAgent) {
    $downloadsFolder = join-path -path $([Environment]::GetFolderPath("UserProfile")) -ChildPath downloads
    $agentFile = "Cohesity_Agent_$(((api get basicClusterInfo).clusterSoftwareVersion).split('_')[0])_Win_x64_Installer.exe"
    $filepath = join-path -path $downloadsFolder -ChildPath $agentFile
    fileDownload 'physicalAgents/download?hostType=kWindows' $filepath
    $remoteFilePath = Join-Path -Path "C:\Windows\Temp" -ChildPath $agentFile
}

foreach ($server in $servers){
    $server = $server.ToString()
    "managing Cohesity Agent on $server"

    ### install Cohesity Agent
    if ($installAgent) {

        ### copy agent installer to server
        "`tcopying agent installer..."
        Copy-Item $filepath \\$server\c$\Windows\Temp

        ### install agent and open firewall port
        "`tinstalling Cohesity agent..."
        $null = Invoke-Command -Computername $server -ArgumentList $remoteFilePath -ScriptBlock {
            param($remoteFilePath)
            if (! $(Get-Service | Where-Object { $_.Name -eq 'CohesityAgent' })) {
                ([WMICLASS]"\\localhost\ROOT\CIMV2:win32_process").Create("$remoteFilePath /type=allcbt /verysilent /supressmsgboxes /norestart")
                New-NetFirewallRule -DisplayName 'Cohesity Agent' -Profile 'Domain' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 50051
            }
        }
    }

    ### register server as physical source
    if($register){
        "`tRegistering as Cohesity protection source..."
        $sourceId = $null
        $phys = api get protectionSources?environments=kPhysical
        $sourceId = ($phys.nodes | Where-Object { $_.protectionSource.name -ieq $server }).protectionSource.id
        if($null -eq $sourceId){
            $newPhysicalSource = @{
                'entity' = @{
                    'type' = 6;
                    'physicalEntity' = @{
                        'name' = $server;
                        'type' = $entityType;
                        'hostType' = 1
                    }
                };
                'entityInfo' = @{
                    'endpoint' = $server;
                    'type' = 6;
                    'hostType' = 1
                };
                'sourceSideDedupEnabled' = $true;
                'throttlingPolicy' = @{
                    'isThrottlingEnabled' = $false
                };
                'forceRegister' = $True
            }
        
            $result = api post /backupsources $newPhysicalSource
            if($null -eq $result){
                continue
            } 
        }    
    }
}