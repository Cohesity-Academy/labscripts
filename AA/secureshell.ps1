# usage: ./cascade.ps1 -vip clusername -username admin -password password 

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$ip,  # ip of the cluster to connect to
    [Parameter(Mandatory = $True)][string]$username,  # support username
    [Parameter(Mandatory = $True)][string]$password # support password
)

# source the cohesity-api helper code
Install-Module -Name Posh-SSH -RequiredVersion 3.0.8 -scope Allusers -Force
$SessionSSH = New-SSHSessions -ComputerName $ip -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$username", (ConvertTo-SecureString -AsPlainText "$password" -Force)) -AcceptKey
Get-SSHSession | fl
$session = Get-SSHSession -Index 0
Start-Sleep 1
$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
Start-Sleep 1
$stream.Write("iris_cli`n")
Start-Sleep 1
$stream.Write("admin`n")
Start-Sleep 1
$stream.Write("cohesity123`n")
Start-Sleep 1
$stream.Write("iris_cli`n")
Start-Sleep 1
$stream.Write("cluster secure-shell enable=false`n")
Remove-SSHSession -SessionId 0
