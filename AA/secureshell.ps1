# usage: ./cascade.ps1 -vip clusername -username admin -password password 

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$ip,  # ip of the cluster to connect to
    [Parameter(Mandatory = $True)][string]$username,  # support username
    [Parameter(Mandatory = $True)][string]$password # support password
)

# source the cohesity-api helper code
$SessionSSH = New-SSHSession -AcceptKey -ComputerName $ip -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$username", (ConvertTo-SecureString -AsPlainText "$password" -Force))
Get-SSHSession | fl
$session = Get-SSHSession -Index 0
Start-Sleep 3
$stream.read()
$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
Start-Sleep 3
$stream.read()
$stream.Write("iris_cli`n")
Start-Sleep 3
$stream.read()
$stream.Write("admin`n")
Start-Sleep 3
$stream.read()
$stream.Write("cohesity123`n")
Start-Sleep 3
$stream.read()
$stream.Write("cluster secure-shell enable=false`n")
start-sleep 3
$stream.read()
$stream.Write("exit`n")
start-sleep 3
$stream.read()
$stream.Write("exit`n")
Remove-SSHSession -SessionId 0
Remove-SSHTrustedHost -HostName $ip
start-sleep 180
