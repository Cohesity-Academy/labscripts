### usage: ./deployWindowsAgent.ps1 -vip bseltzve01 -username admin -serverName server.name.local -package (deb,rpm) [ -installAgent ] [ -register ] [ -registerSQL ] [ -serviceAccount mydomain.net\myuser ]
### provide a list of servers in a text file
### specify any of -installAgent -register -registerSQL -serviceAccount -storePassword

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)][string]$vip,
    [Parameter(Mandatory=$True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password,
    [Parameter()][string]$package,
    [Parameter()][string]$serverName,
    [Parameter()][string]$filepath = "c:\",
    [Parameter()][ValidateSet('onlyagent','volcbt','fscbt','allcbt')][string]$cbtType = 'allcbt',
    [Parameter()][string]$tempPath = 'admin$\Temp'
)

if($serverList){
    $servers = get-content $serverList
    }elseif($serverName){
        $servers = @($serverName)
    }else{
        Write-Warning "No Servers Specified"
        exit
    }
    
### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
Import-Module $(Join-Path -Path $PSScriptRoot -ChildPath userRights.psm1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -tenant $tenant -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

if $package = deb {
    $beginning = "cohesity-agent_"
    $ending = "-1_amd64.deb"
}
if $package = rpm {
    $beginning = "el-cohesity_"
    $ending = "-1.x86_64.rpm"
}

### get protection sources
$sources = api get protectionSources/registrationInfo

### download agent installer to local host
if($installAgent){
    if($filepath){
        $agentFile = $filepath
    }else{
        $downloadsFolder = join-path -path $([Environment]::GetFolderPath("UserProfile")) -ChildPath downloads
        $agentFile = "$beginning + $(((api get cluster).clusterSoftwareVersion).split('_')[0]) + $ending"
        $filepath = join-path -path $downloadsFolder -ChildPath $agentFile
        fileDownload 'physicalAgents/download?hostType=kLinux' $filepath
    }
}

foreach ($server in $servers){
    $server = $server.ToString()
    "managing Cohesity Agent on $server"
    $remotePath = "\\$($server)\$($tempPath)"
    $remoteFilePath = Join-Path -Path "\\$($server)\$($tempPath)" -ChildPath  "Cohesity_Agent_$(((api get cluster).clusterSoftwareVersion).split('_')[0])_Win_x64_Installer.exe"
    ### install Cohesity Agent
    if($installAgent){
        ### copy agent installer to server
        "`tcopying agent installer $agentFile to $remotePath..."
        Copy-Item $filepath $remotePath

        ### install agent and open firewall port
        "`tinstalling Cohesity agent..."
        $null = Invoke-Command -Computername $server -ArgumentList $remoteFilePath, $cbtType -ScriptBlock {
            param($remoteFilePath, $cbtType)
            # if(! $(Get-Service | Where-Object { $_.Name -eq 'CohesityAgent' })){
                ([WMICLASS]"\\localhost\ROOT\CIMV2:win32_process").Create("$remoteFilePath /type=$cbtType /verysilent /suppressmsgboxes /NORESTART")
                New-NetFirewallRule -DisplayName 'Cohesity Agent' -Profile 'Domain' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 50051
            # }
        }
    }

# Set the credentials
$Password = ConvertTo-SecureString 'Password1' -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ('root', $Password)

# Set local file path, SFTP path, and the backup location path which I assume is an SMB path
$FilePath = "C:\FileDump\test.txt"
$SftpPath = '/Outbox'
$SmbPath = '\\filer01\Backup'

# Set the IP of the SFTP server
$SftpIp = '10.209.26.105'

# Load the Posh-SSH module
Import-Module C:\Temp\Posh-SSH

# Establish the SFTP connection
$ThisSession = New-SFTPSession -ComputerName $SftpIp -Credential $Credential

# Upload the file to the SFTP path
Set-SFTPFile -SessionId ($ThisSession).SessionId -LocalFile $FilePath -RemotePath $SftpPath

#Disconnect all SFTP Sessions
Get-SFTPSession | % { Remove-SFTPSession -SessionId ($_.SessionId) }

# Copy the file to the SMB location
Copy-Item -Path $FilePath -Destination $SmbPath


}
