### usage: ./deploylinuxagent.ps1 -vip bseltzve01 -username admin -password pass -serverName server.name.local -package (DEB,RPM) -linuser username -linpassword pass

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True)][string]$vip,
    [Parameter(Mandatory=$True)][string]$username,
    [Parameter(Mandatory=$True)][string]$linuser,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$password,
    [Parameter()][string]$linpass,
    [Parameter()][string]$package, # DEB RPM SCRIPT
    [Parameter()][string]$serverName,
    [Parameter()][string]$filepath,
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

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password 

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

### get protection sources
$sources = api get protectionSources/registrationInfo

### download agent installer to local host
if($filepath){
        $agentFile = $filepath
    }else{
        $downloadsFolder = join-path -path $([Environment]::GetFolderPath("UserProfile")) -ChildPath downloads
        $agentFile = "cohesity-agent_$(((api get cluster).clusterSoftwareVersion).split('_')[0]).$package"
        $filepath = join-path -path $downloadsFolder -ChildPath $agentFile
        fileDownload "physicalAgents/download?hostType=kLinux&pkgType=k$package" $filepath
    }


# Set the credentials
#$Password = ConvertTo-SecureString 'Password1' -AsPlainText -Force
#$Credential = New-Object System.Management.Automation.PSCredential ('root', $Password)

# Set local file path, SFTP path, and the backup location path which I assume is an SMB path
$filepath = "cohesity-agent_$(((api get cluster).clusterSoftwareVersion).split('_')[0]).$package"
$SftpPath = '/home/coh-student'

# Set the IP of the SFTP server
$SftpIp = $servername

# Load the Posh-SSH module
Import-Module Posh-SSH

# Establish the SFTP connection
$ThisSession = New-SFTPSession -AcceptKey -ComputerName $SftpIp -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$linuser", (ConvertTo-SecureString -AsPlainText "$linpass" -Force))

# Upload the file to the SFTP path
Set-SFTPItem -SessionId ($ThisSession).SessionId -Path $FilePath -Destination $SftpPath

#Disconnect all SFTP Sessions
Get-SFTPSession | % { Remove-SFTPSession -SessionId ($_.SessionId) }
Remove-SSHSession -SessionId 0
Remove-SSHTrustedHost -HostName $ip
#Install package
$SessionSSH = New-SSHSession -AcceptKey -ComputerName  $SftpIp -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$linuser", (ConvertTo-SecureString -AsPlainText "$linpass" -Force))
Get-SSHSession | fl
$session = Get-SSHSession -Index 0
Start-Sleep 3
$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
Start-Sleep 3
$stream.Write("sudo dpkg -i $FilePath")
Start-Sleep 15
$stream.Write("exit`n")
Remove-SSHSession -SessionId 0
Remove-SSHTrustedHost -HostName $ip
